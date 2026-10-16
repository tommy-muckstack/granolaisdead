import AppKit
import Combine
import SwiftUI

/// Navigation + the meeting lifecycle (new note → record → stop → notes).
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Route: Equatable, Hashable { case home, chat, folder(UUID), note(UUID) }

    @Published var route: Route = .home
    @Published var back: [Route] = []
    @Published var sidebarVisible = UserDefaults.standard.object(forKey: "sidebarVisible") as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarVisible, forKey: "sidebarVisible") }
    }
    @Published var searchPresented = false
    /// Notes currently being enhanced.
    @Published private(set) var enhancing: Set<UUID> = []
    /// Per-note view mode: true = enhanced notes, false = my notes.
    @Published var showEnhanced: [UUID: Bool] = [:]
    /// A question typed on Home/Chat waiting for the Chat screen.
    @Published var pendingQuestion: String?
    /// Dev hook (GID_ROUTE): open a note's "transcript" or "chat" panel.
    var debugPanel: String?

    let store = NoteStore.shared
    let recorder = MeetingRecorder.shared

    init() {
        MeetingRecorder.shared.onAutoStop = { [weak self] reason in
            guard let self, let id = self.recorder.noteID else { return }
            self.stopRecording()
            let msg: String
            switch reason {
            case .silence(let m): msg = "Stopped transcribing after \(m) minutes of silence."
            case .callEnded: msg = "The call ended, so transcription stopped."
            }
            Toast.show(msg, systemImage: "pause.circle", actionLabel: "Resume", action: { [weak self] in self?.startRecording(id) })
            Analytics.track("app_meeting_auto_stopped", ["reason": { if case .callEnded = reason { return "call_ended" } else { return "silence" } }()])
        }
    }

    func go(_ r: Route) {
        guard r != route else { return }
        back.append(route); if back.count > 30 { back.removeFirst() }
        route = r
        MainWindow.shared.show()
    }

    func goBack() { route = back.popLast() ?? .home }

    // MARK: Notes

    @discardableResult
    func newNote(record: Bool = false, event: CalendarStore.Event? = nil, folder: UUID? = nil) -> UUID {
        if let event, let existing = store.notes.first(where: { $0.calendarEventID == event.id }) {
            go(.note(existing.id))
            if record { startRecording(existing.id) }
            return existing.id
        }
        let template = SettingsStore.shared.defaultTemplate
        let n = store.create { n in
            n.templateID = template
            n.folderID = folder
            if let event {
                n.title = event.title; n.calendarEventID = event.id; n.calendarTitle = event.title
                n.attendees = event.attendees
            }
        }
        go(.note(n.id))
        Analytics.track("app_note_created", ["from_calendar": event != nil, "record": record])
        if record { startRecording(n.id) }
        return n.id
    }

    func startRecording(_ id: UUID) {
        if recorder.startingNoteID != nil { return }
        if recorder.isRecording {
            if recorder.noteID == id { return }
            stopRecording()
        }
        Task { await recorder.start(noteID: id) }
    }

    func stopRecording() {
        guard let id = recorder.noteID else { recorder.stop(); return } // cancels a start in progress
        recorder.stop { [weak self] in
            guard let self, let n = self.store.note(id) else { return }
            if SettingsStore.shared.autoEnhance, n.hasTranscript || !n.myNotes.isEmpty { self.enhance(id) }
        }
    }

    func toggleRecording(_ id: UUID) {
        if recorder.noteID == id || recorder.startingNoteID == id { stopRecording() } else { startRecording(id) }
    }

    /// Enhance requests that arrived while one was running for the same note.
    private var enhanceAgain: Set<UUID> = []

    func enhance(_ id: UUID, template: String? = nil) {
        if let template { store.update(id, immediately: true) { $0.templateID = template } }
        // Already running: run once more when it finishes, with the latest
        // transcript and template, instead of dropping the request.
        guard !enhancing.contains(id) else { enhanceAgain.insert(id); return }
        guard let n = store.note(id) else { return }
        guard n.hasTranscript || !n.myNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Toast.show("Record or type something first, then generate notes.", systemImage: "sparkles")
            return
        }
        enhancing.insert(id)
        showEnhanced[id] = true
        Task {
            let e = await NoteEngine.enhance(n)
            store.update(id, immediately: true) { note in
                note.enhanced = e
                if note.title.trimmingCharacters(in: .whitespaces).isEmpty { note.title = Self.suggestTitle(note) }
            }
            enhancing.remove(id)
            if enhanceAgain.remove(id) != nil { enhance(id) }
        }
    }

    func delete(_ id: UUID) {
        if recorder.noteID == id || recorder.startingNoteID == id { recorder.stop() }
        store.delete(id)
        if route == .note(id) { route = .home }
        back.removeAll { $0 == .note(id) }
    }

    func isShowingEnhanced(_ n: Note) -> Bool {
        showEnhanced[n.id] ?? (n.enhanced != nil && recorder.noteID != n.id)
    }

    /// First meaningful words of the transcript or notes ("Pricing review").
    static func suggestTitle(_ n: Note) -> String {
        if let heading = n.enhanced?.sections.first(where: { !["overview", "notes", "discussion", "summary"].contains($0.heading.lowercased()) })?.heading {
            return String(heading.prefix(60))
        }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return "Meeting on \(f.string(from: n.startedAt ?? n.createdAt))"
    }
}
