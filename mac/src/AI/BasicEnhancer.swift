import Foundation

/// The no-model fallback (ported from the old web app): extractive. Your own
/// lines are kept and get the best-matching transcript sentence attached;
/// key points are frequency-scored transcript sentences; actions and
/// decisions are pattern-matched. Quotes rather than paraphrases.
enum BasicEnhancer {
    struct Sentence { let speaker: String; let text: String }

    private static let stop: Set<String> = Set("the of and to a in is it you that he was for on are with as i his they be at one have this from or had by not but what some we can out other were all there when up use your how said an each she which do their time if will way about many then them would like so these her make see him has more could go come did no most my over know than who may been now find just yeah okay ok um uh really think also get got going".split(separator: " ").map(String.init))

    static func content(_ s: String) -> [String] {
        EchoFilter.words(s).map { $0.hasSuffix("'s") ? String($0.dropLast(2)) : $0 }.filter { !stop.contains($0) }
    }

    static func sentences(_ note: Note) -> [Sentence] {
        var out: [Sentence] = []
        for seg in note.transcript {
            var buf = ""
            for ch in seg.text {
                buf.append(ch)
                if ".!?".contains(ch) { push(&out, seg.speaker, buf); buf = "" }
            }
            push(&out, seg.speaker, buf)
        }
        return out
    }

    private static func push(_ out: inout [Sentence], _ speaker: String, _ raw: String) {
        let t = raw.trimmingCharacters(in: .whitespaces)
        if t.split(separator: " ").count >= 3 { out.append(Sentence(speaker: speaker, text: t)) }
    }

    static func clean(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"^(?i)(so|and|but|well|okay|ok|yeah|um|uh|like|right)[, ]+"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[.!?]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    private static func matches(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static let action = #"\b(i'll|i will|we'll|we will|let's|need to|needs to|have to|going to|gonna|action item|follow up|follow-up|can you|could you|will send|will share|will schedule|will draft|will review)\b\s+(\S+\s+){0,2}(send|schedule|share|review|draft|prepare|update|book|set up|write|create|email|call|check|fix|ship|deliver|finish|confirm|circulate|loop in|reach out|follow up|research|look into|investigate|add|build|test|own|handle|lead|monitor|coordinate|organize|document)\b"#
    static let decision = #"\b(decided|agreed|we're going with|let's go with|the plan is|settled on|approved|final decision|we'll go with|going ahead with|signed off)\b"#

    static func keyPoints(_ s: [Sentence], max: Int, exclude: Set<String>) -> [String] {
        var freq: [String: Int] = [:]
        for x in s { for w in Set(content(x.text)) { freq[w, default: 0] += 1 } }
        let scored: [(Int, Double, String)] = s.enumerated().compactMap { (i, x) -> (Int, Double, String)? in
            let n = x.text.split(separator: " ").count
            guard n >= 6, n <= 40, !x.text.hasSuffix("?"), !exclude.contains(x.text) else { return nil }
            let cw = content(x.text)
            let raw = cw.reduce(0.0) { $0 + Double(freq[$1] ?? 1) - 0.5 } / sqrt(Double(Swift.max(cw.count, 1)))
            return (i, raw + (x.text.rangeOfCharacter(from: .decimalDigits) != nil ? 1.5 : 0), x.text)
        }
        return scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(max).sorted { $0.0 < $1.0 }.map { clean($0.2) }
    }

    static func enhance(_ note: Note, template: NoteTemplate) -> EnhancedNotes {
        let sents = sentences(note)
        var taken = Set<String>()
        var actions: [EnhancedNotes.Line] = [], decisions: [EnhancedNotes.Line] = [], questions: [EnhancedNotes.Line] = []
        for x in sents {
            let n = x.text.split(separator: " ").count
            if x.text.hasSuffix("?") {
                if n >= 4, questions.count < 5 { questions.append(.init(text: clean(x.text) + "?")) }
                continue
            }
            if n >= 4, n <= 32, matches(x.text, action), !matches(x.text, #"^(i think|i guess|maybe|if)\b"#), actions.count < 10 {
                let owner = matches(x.text, #"^(yes|yeah|sure|okay|ok)?[, ]*(i'll|i will|i can|let me)\b"#) ? x.speaker : nil
                actions.append(.init(text: (owner.map { "\($0): " } ?? "") + clean(x.text), done: false)); taken.insert(x.text)
            } else if matches(x.text, decision), decisions.count < 8 {
                decisions.append(.init(text: clean(x.text))); taken.insert(x.text)
            }
        }
        var lines: [EnhancedNotes.Line] = []
        var used = Set<String>()
        for l in note.myNotes.split(separator: "\n").map({ $0.trimmingCharacters(in: CharacterSet(charactersIn: " -*•·\t")) }).filter({ !$0.isEmpty }) {
            lines.append(.init(text: l, mine: true))
            let lw = Set(content(l))
            if let best = sents.filter({ !taken.contains($0.text) && !used.contains($0.text) })
                .map({ ($0, Set(content($0.text)).intersection(lw).count) }).max(by: { $0.1 < $1.1 }), best.1 >= 2 {
                lines.append(.init(text: clean(best.0.text), level: 1)); used.insert(best.0.text)
            }
        }
        for k in keyPoints(sents, max: min(10, Swift.max(0, sents.count / 5)), exclude: taken.union(used)) {
            lines.append(.init(text: k))
        }
        var sections: [EnhancedNotes.Section] = []
        if !lines.isEmpty { sections.append(.init(heading: "Notes", lines: lines)) }
        if !decisions.isEmpty { sections.append(.init(heading: "Decisions", lines: decisions)) }
        if !actions.isEmpty { sections.append(.init(heading: "Action items", lines: actions)) }
        if !questions.isEmpty { sections.append(.init(heading: "Open questions", lines: questions)) }
        if sections.isEmpty { sections = [.init(heading: "Notes", lines: [.init(text: "Not enough was said to write notes yet.")])] }
        return EnhancedNotes(sections: sections, engine: "basic")
    }

    static func answer(_ question: String, note: Note) -> String {
        let q = Set(content(question))
        guard !q.isEmpty else { return "Ask about something specific, like a person, a number or a decision." }
        var pool: [(String, Double)] = note.myNotes.split(separator: "\n").map { (String($0), 1.3) }
        pool += sentences(note).map { ("\($0.speaker): \($0.text)", 1.0) }
        let best = pool.map { ($0.0, Double(Set(content($0.0)).intersection(q).count) * $0.1) }
            .filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(3)
        guard !best.isEmpty else { return "I couldn’t find that in this meeting’s notes or transcript." }
        return "From the transcript:\n" + best.map { "- " + $0.0 }.joined(separator: "\n")
    }
}
