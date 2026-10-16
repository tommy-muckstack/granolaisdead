import Foundation

/// A template shapes enhanced notes: which sections, in which order, plus a
/// short focus line for the model. Built in only (no editor yet).
struct NoteTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let sections: [String]
    let guidance: String

    static let auto = NoteTemplate(id: "auto", name: "Auto", symbol: "✨",
        sections: ["Overview", "Discussion", "Decisions", "Action items"],
        guidance: "Pick section headings that fit the conversation best; group related points under topic headings instead of a generic \"Discussion\" when that reads better.")

    static let all: [NoteTemplate] = [
        auto,
        NoteTemplate(id: "one-on-one", name: "1 to 1", symbol: "👥",
            sections: ["Top of mind", "Updates and wins", "Challenges", "Feedback", "Next steps"],
            guidance: "Capture how the other person is doing, what they need, and any feedback given in either direction."),
        NoteTemplate(id: "standup", name: "Stand-up", symbol: "🧍",
            sections: ["Yesterday", "Today", "Blockers", "Action items"],
            guidance: "Group updates by person when names are clear."),
        NoteTemplate(id: "weekly-team", name: "Weekly Team Meeting", symbol: "📅",
            sections: ["Announcements", "Project updates", "Discussion", "Decisions", "Action items"],
            guidance: "Keep project updates grouped by project."),
        NoteTemplate(id: "customer-discovery", name: "Customer: Discovery", symbol: "💵",
            sections: ["About them", "Current process and tools", "Pain points", "Needs and requests", "Budget and timeline", "Next steps"],
            guidance: "Quote the customer's own words for pain points when possible."),
        NoteTemplate(id: "sales-call", name: "Customer: Sales call", symbol: "🤝",
            sections: ["Context", "Requirements", "Objections and concerns", "Decision process", "Next steps"],
            guidance: "Note who decides, budget, timing and competitors mentioned."),
        NoteTemplate(id: "user-interview", name: "User interview", symbol: "🎙️",
            sections: ["Background", "Key insights", "Pain points", "Quotes", "Follow-ups"],
            guidance: "Prefer direct quotes under Quotes."),
        NoteTemplate(id: "hiring", name: "Hiring", symbol: "💼",
            sections: ["Background", "Experience highlights", "Strengths", "Concerns", "Questions they asked", "Next steps"],
            guidance: "Stay factual; no hiring recommendation unless one was said."),
        NoteTemplate(id: "investor", name: "VC: Pitch", symbol: "🚀",
            sections: ["Company overview", "Traction and metrics", "Questions raised", "Concerns", "Next steps"],
            guidance: "Record every number exactly as said."),
        NoteTemplate(id: "board", name: "Board meeting", symbol: "🏛️",
            sections: ["Highlights", "Financials", "Key discussions", "Decisions and votes", "Action items"],
            guidance: "List decisions and votes precisely."),
    ]

    static func find(_ id: String) -> NoteTemplate { all.first { $0.id == id } ?? auto }
}
