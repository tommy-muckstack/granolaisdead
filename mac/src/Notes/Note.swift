import Foundation

/// One meeting (or a plain note): what the user typed, the transcript, and the
/// enhanced notes generated from both. Stored as one JSON file per note.
struct Note: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Set while/after audio was captured.
    var startedAt: Date?
    var endedAt: Date?
    var calendarEventID: String?
    var calendarTitle: String?
    var attendees: [Attendee] = []
    var folderID: UUID?
    var templateID: String = NoteTemplate.auto.id
    /// The user's own notes (plain text, one thought per line; "- " bullets allowed).
    var myNotes: String = ""
    var transcript: [TranscriptSegment] = []
    var enhanced: EnhancedNotes?
    var chat: [ChatMessage] = []

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "New note" : t
    }

    var hasTranscript: Bool { !transcript.isEmpty }

    var durationSeconds: TimeInterval? {
        guard let s = startedAt else { return nil }
        return (endedAt ?? Date()).timeIntervalSince(s)
    }

    /// Transcript as "Speaker: text" lines, for models and export.
    var transcriptText: String {
        transcript.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
    }

    var transcriptTextWithTimes: String {
        transcript.map { "[\(Self.stamp($0.start))] \($0.speaker): \($0.text)" }.joined(separator: "\n")
    }

    static func stamp(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct Attendee: Codable, Hashable {
    var name: String
    var email: String?

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first.map(String.init) }.joined()
        return s.isEmpty ? "?" : s.uppercased()
    }
}

struct TranscriptSegment: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    /// "Me" for the microphone track; "Them" / "Speaker N" for computer audio.
    var speaker: String
    var source: Source
    var start: Double
    var end: Double
    var text: String

    enum Source: String, Codable { case mic, system }
}

/// Granola-style enhanced notes: headed sections of bullets. Lines the user
/// wrote keep `mine = true` (rendered in full black); generated lines are
/// rendered in the softer gray.
struct EnhancedNotes: Codable, Equatable {
    var sections: [Section]
    var generatedAt: Date = Date()
    /// "on-device", "claude:<model>", "openai:<model>" or "basic".
    var engine: String

    struct Section: Codable, Equatable, Identifiable {
        var id: UUID = UUID()
        var heading: String
        var lines: [Line]
    }

    struct Line: Codable, Equatable, Identifiable {
        var id: UUID = UUID()
        var text: String
        var mine: Bool = false
        var level: Int = 0
        var done: Bool? // action items carry a checkbox
    }

    var markdown: String {
        var out: [String] = []
        for s in sections {
            out.append("### \(s.heading)")
            for l in s.lines {
                let indent = String(repeating: "  ", count: l.level)
                if let done = l.done { out.append("\(indent)- [\(done ? "x" : " ")] \(l.text)") }
                else { out.append("\(indent)- \(l.text)") }
            }
            out.append("")
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}

struct ChatMessage: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var role: Role
    var text: String
    var at: Date = Date()
    enum Role: String, Codable { case user, assistant }
}

struct Folder: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
}
