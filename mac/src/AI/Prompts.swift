import Foundation

/// Our own prompts (written for this app, not copied). Rules that matter for
/// small on-device models are repeated next to the input: they forget system
/// instructions on long inputs.
enum Prompts {
    static func enhanceInstructions(template: NoteTemplate) -> String {
        """
        You write meeting notes for the person who recorded the meeting. You get their own rough notes and a transcript. \
        "Me" in the transcript is the note taker; "Them" is everyone else on the call.

        Write clear, skimmable notes in Markdown:
        - Use these sections, in this order, as "### " headings: \(template.sections.joined(separator: " | ")). \
        Skip a section when the meeting gave it no content. Add one extra section only if something important fits nowhere else.
        - Under each heading write short "- " bullets in terse note style (one fact per bullet, under 20 words). \
        Paraphrase and compress; never copy whole sentences from the transcript. Indent sub-points with two spaces.
        - Keep every line of the note taker's own notes, word for word, as a bullet in the section it belongs to, \
        and add supporting detail from the transcript as indented sub-bullets under it.
        - Action items are "- [ ] Owner: task, deadline" lines. Owner is "Me" or a name said in the meeting; include a deadline only if it was said.
        - Only write what was actually said. Never invent names, numbers, dates or decisions. If unsure, leave it out.
        - No preamble, no closing remarks, no title line.
        \(template.guidance.isEmpty ? "" : "\nFocus: \(template.guidance)")
        """
    }

    static func enhanceInput(_ note: Note, transcript: String) -> String {
        let title = note.title.trimmingCharacters(in: .whitespaces)
        let people = note.attendees.map(\.name).joined(separator: ", ")
        let mine = note.myNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        Meeting: \(title.isEmpty ? "Untitled" : title)\(people.isEmpty ? "" : "\nAttendees: \(people)")

        <<<MY NOTES>>>
        \(mine.isEmpty ? "(none)" : mine)
        <<<END MY NOTES>>>

        <<<TRANSCRIPT>>>
        \(transcript.isEmpty ? "(no transcript)" : transcript)
        <<<END TRANSCRIPT>>>

        Write the notes now: "### " headings and short paraphrased "- " bullets only, "- [ ] Owner: task" for action items, keep my notes word for word, never invent facts.
        """
    }

    static let condenseInstructions = """
    You condense a slice of a meeting transcript into terse factual bullets. Keep: decisions, numbers, names, dates, \
    commitments ("who will do what by when"), problems raised, open questions. Drop small talk. Keep the speaker \
    label ("Me"/"Them") on commitments. Output only "- " bullets, at most 12. Never invent anything.
    """

    static let chatInstructions = """
    You answer questions about one meeting using only its notes and transcript below. Be brief and specific: \
    a short paragraph or a few bullets. Quote the transcript when it helps. If the answer is not in the meeting, \
    say so plainly. "Me" is the person asking; "Them" is everyone else.
    """

    static func chatContext(_ note: Note) -> String {
        var s = "Meeting: \(note.displayTitle)\n"
        if let e = note.enhanced { s += "\n<<<NOTES>>>\n\(e.markdown)<<<END NOTES>>>\n" }
        else if !note.myNotes.isEmpty { s += "\n<<<MY NOTES>>>\n\(note.myNotes)\n<<<END MY NOTES>>>\n" }
        s += "\n<<<TRANSCRIPT>>>\n\(note.transcriptTextWithTimes)\n<<<END TRANSCRIPT>>>\n"
        return s
    }

    static func chatTurn<C: Collection>(_ question: String, history: C) -> String where C.Element == ChatMessage {
        var s = ""
        if !history.isEmpty {
            s += "\nEarlier in this chat:\n"
            for m in history { s += "\(m.role == .user ? "Q" : "A"): \(m.text)\n" }
        }
        return s + "\nQuestion: \(question)\nAnswer from the meeting only."
    }

    /// Transcript lines most related to the question, in order, within budget.
    static func relevantExcerpt(_ note: Note, question: String, budget: Int) -> String {
        let q = Set(EchoFilter.words(question))
        let lines = note.transcript.map { "[\(Note.stamp($0.start))] \($0.speaker): \($0.text)" }
        let scored = lines.enumerated().map { (i, l) in (i, Set(EchoFilter.words(l)).intersection(q).count) }
        var keep = Set<Int>(), used = 0
        for (i, score) in scored.sorted(by: { $0.1 > $1.1 }) where score > 0 {
            for j in max(0, i - 1)...min(lines.count - 1, i + 1) where !keep.contains(j) {
                guard used + lines[j].count < budget else { break }
                keep.insert(j); used += lines[j].count
            }
        }
        let excerpt = keep.sorted().map { lines[$0] }.joined(separator: "\n")
        return "Meeting: \(note.displayTitle)\n\(note.myNotes.isEmpty ? "" : "\n<<<MY NOTES>>>\n\(note.myNotes)\n<<<END MY NOTES>>>\n")\n<<<TRANSCRIPT EXCERPT>>>\n\(excerpt)\n<<<END>>>\n"
    }

    /// Split on line boundaries into windows of at most `size` characters.
    static func windows(_ text: String, size: Int) -> [String] {
        var out: [String] = [], cur = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if cur.count + line.count + 1 > size, !cur.isEmpty { out.append(cur); cur = "" }
            cur += (cur.isEmpty ? "" : "\n") + line
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }
}
