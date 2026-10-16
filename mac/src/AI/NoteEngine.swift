import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns "what you typed + what was said" into Granola-style enhanced notes,
/// and answers questions about a meeting.
///
/// Engine order: the user's own Claude/OpenAI key when they turned it on in
/// Settings → AI, then Apple's on-device model (macOS 26+, Apple Intelligence
/// on), then a basic extractive pass that runs anywhere. Nothing is sent
/// anywhere unless the user pasted their own key.
@MainActor
enum NoteEngine {
    enum Kind: String { case hosted, onDevice = "on-device", basic }

    static var onDeviceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) { return SystemLanguageModel.default.availability == .available }
        #endif
        return false
    }

    static func currentKind() -> Kind {
        if WritingModels.current(for: .meetingNotes) != nil { return .hosted }
        return onDeviceAvailable ? .onDevice : .basic
    }

    // MARK: Enhance

    static func enhance(_ note: Note) async -> EnhancedNotes {
        let template = NoteTemplate.find(note.templateID)
        let started = Date()
        var result: EnhancedNotes?
        var engine = "basic"
        if let provider = WritingModels.current(for: .meetingNotes) {
            do {
                let r = try await provider.generate(WritingRequest(
                    instructions: Prompts.enhanceInstructions(template: template),
                    input: Prompts.enhanceInput(note, transcript: note.transcriptTextWithTimes),
                    jsonSchema: nil, deadline: 180, purpose: .meetingNotes))
                result = parse(r.text, note: note, engine: provider.id)
                engine = provider.id
            } catch {
                NSLog("GranolaIsDead [Notes] hosted failed: \(error)")
            }
        }
        if result == nil, onDeviceAvailable, let text = await onDeviceEnhance(note, template: template) {
            result = parse(text, note: note, engine: "on-device")
            engine = "on-device"
        }
        let final = result.flatMap { $0.sections.isEmpty ? nil : keepOwnLines($0, note: note) } ?? BasicEnhancer.enhance(note, template: template)
        Analytics.track("app_notes_enhanced", ["engine": engine.split(separator: ":").first.map(String.init) ?? engine,
                                               "template": template.id,
                                               "seconds_bucket": Int(Date().timeIntervalSince(started)) < 20 ? "lt_20s" : "gte_20s"])
        return final
    }

    private static func onDeviceEnhance(_ note: Note, template: NoteTemplate) async -> String? {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else { return nil }
        // The on-device model has a small context: summarize long transcripts
        // window by window first, then write the notes from those summaries.
        // Never truncate — dropping the tail was My Man's worst summary bug.
        var material = note.transcriptTextWithTimes
        if material.count > 7000 {
            var parts: [String] = []
            for window in Prompts.windows(note.transcriptTextWithTimes, size: 6000) {
                let s = LanguageModelSession(instructions: Prompts.condenseInstructions)
                do { parts.append(try await s.respond(to: "<<<TRANSCRIPT>>>\n\(window)\n<<<END>>>").content) }
                catch {
                    // A refused/overflowed window still counts: keep its most
                    // informative sentences instead of silently losing it.
                    NSLog("GranolaIsDead [Notes] condense window failed: \(error)")
                    let lines = window.split(separator: "\n").map(String.init)
                    let picked = BasicEnhancer.keyPoints(lines.map { BasicEnhancer.Sentence(speaker: "", text: $0) }, max: 6, exclude: [])
                    parts.append(picked.map { "- " + $0 }.joined(separator: "\n"))
                }
            }
            guard parts.contains(where: { !$0.isEmpty }) else { return nil }
            material = parts.joined(separator: "\n")
            while material.count > 7000 {
                var next: [String] = []
                for window in Prompts.windows(material, size: 6000) {
                    let s = LanguageModelSession(instructions: Prompts.condenseInstructions)
                    if let r = try? await s.respond(to: "<<<TRANSCRIPT>>>\n\(window)\n<<<END>>>") { next.append(r.content) }
                }
                let joined = next.joined(separator: "\n")
                if joined.count >= material.count { break }
                material = joined
            }
        }
        let session = LanguageModelSession(instructions: Prompts.enhanceInstructions(template: template))
        do {
            var trimmed = note
            if trimmed.myNotes.count > 3000 { trimmed.myNotes = String(trimmed.myNotes.prefix(3000)) } // on-device context is small
            let r = try await session.respond(to: Prompts.enhanceInput(trimmed, transcript: material))
            return r.content
        } catch {
            NSLog("GranolaIsDead [Notes] on-device failed: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Markdown (### headings, "- " bullets, "- [ ]" actions) → sections.
    /// Lines that repeat what the user typed are marked theirs.
    static func parse(_ markdown: String, note: Note, engine: String) -> EnhancedNotes {
        let mine = note.myNotes.split(separator: "\n").map { normalize(String($0)) }.filter { $0.count > 2 }
        var sections: [EnhancedNotes.Section] = []
        var current: EnhancedNotes.Section?
        for raw in markdown.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                if let c = current, !c.lines.isEmpty { sections.append(c) }
                let heading = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                current = .init(heading: heading.replacingOccurrences(of: "**", with: ""), lines: [])
                continue
            }
            let indent = line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 2 : 1) }
            var text = trimmed
            var done: Bool?
            var hadMarker = false
            while let r = text.range(of: #"^([-*•]|\d+[.)])\s+"#, options: .regularExpression) { text.removeSubrange(r); hadMarker = true }
            if let r = text.range(of: #"^\[( |x|X)\]\s*"#, options: .regularExpression) {
                done = text[r].lowercased().contains("x"); text.removeSubrange(r)
            } else if !hadMarker, current == nil, sections.isEmpty {
                continue // preamble like "Here are your notes:"
            }
            // "[Me] will…" / "**Sam**: …" → "Me: will…" style owner prefix.
            if let r = text.range(of: #"^\[([^\]]{1,40})\]:?\s*"#, options: .regularExpression) {
                let owner = text[r].trimmingCharacters(in: CharacterSet(charactersIn: "[]: "))
                text.replaceSubrange(r, with: owner + ": ")
            }
            if done == nil, let h = current?.heading.lowercased(),
               ["action", "next step", "follow", "to-do", "todo"].contains(where: h.contains) { done = false }
            text = text.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            let n = normalize(text)
            let isMine = mine.contains { $0 == n || (n.count > 8 && ($0.contains(n) || n.contains($0)) && min($0.count, n.count) * 2 > max($0.count, n.count)) }
            if current == nil { current = .init(heading: "Notes", lines: []) }
            current?.lines.append(.init(text: text, mine: isMine, level: min(2, indent / 2), done: done))
        }
        if let c = current, !c.lines.isEmpty { sections.append(c) }
        return EnhancedNotes(sections: sections, engine: engine)
    }

    /// Granola never loses what you typed. Any of your lines the model left
    /// out goes back in, in full ink, under the section it shares most words
    /// with (the first section when nothing matches).
    static func keepOwnLines(_ e: EnhancedNotes, note: Note) -> EnhancedNotes {
        var e = e
        let lines = note.myNotes.split(separator: "\n").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " -*•·\t")) }.filter { !$0.isEmpty }
        for l in lines.reversed() {
            let n = normalize(l)
            let present = e.sections.contains { $0.lines.contains { $0.mine && (normalize($0.text) == n || normalize($0.text).contains(n)) } }
            guard !present, !e.sections.isEmpty else { continue }
            let w = Set(BasicEnhancer.content(l))
            let best = e.sections.indices.max { a, b in
                let sa = e.sections[a].lines.reduce(0) { $0 + Set(BasicEnhancer.content($1.text)).intersection(w).count }
                let sb = e.sections[b].lines.reduce(0) { $0 + Set(BasicEnhancer.content($1.text)).intersection(w).count }
                return sa < sb
            } ?? 0
            let text = l.prefix(1).uppercased() + l.dropFirst()
            e.sections[best].lines.insert(.init(text: text, mine: true), at: 0)
        }
        return e
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: #"^[\s\-*•·]+"#, with: "", options: .regularExpression)
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: Ask

    static func answer(_ question: String, note: Note, history: [ChatMessage]) async -> String {
        let context = Prompts.chatContext(note)
        if let provider = WritingModels.current(for: .brainChat) {
            if let r = try? await provider.generate(WritingRequest(
                instructions: Prompts.chatInstructions, input: context + Prompts.chatTurn(question, history: history),
                jsonSchema: nil, deadline: 90, purpose: .brainChat)) {
                return r.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), onDeviceAvailable {
            let trimmed = context.count > 9000 ? Prompts.relevantExcerpt(note, question: question, budget: 8000) : context
            let s = LanguageModelSession(instructions: Prompts.chatInstructions)
            if let r = try? await s.respond(to: trimmed + Prompts.chatTurn(question, history: history.suffix(4))) {
                return r.content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        #endif
        return BasicEnhancer.answer(question, note: note)
    }
}
