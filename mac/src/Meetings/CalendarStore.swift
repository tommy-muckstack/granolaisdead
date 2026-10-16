import AppKit
import Combine
import EventKit

/// Upcoming meetings from every account macOS Calendar knows (Google,
/// Outlook, iCloud) through EventKit — no OAuth of our own. A fresh
/// EKEventStore per read (cached stores go stale); `.EKEventStoreChanged`
/// wakes us, a 5-minute timer is the backstop.
@MainActor
final class CalendarStore: ObservableObject {
    static let shared = CalendarStore()

    struct Event: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let attendees: [Attendee]
        let joinURL: URL?
        let calendarColor: NSColor?
        var isNow: Bool { start <= Date() && end > Date() }
    }

    @Published private(set) var upcoming: [Event] = []
    @Published private(set) var authorized = Permissions.calendarGranted
    /// Fired ~1 minute before an event that has attendees or a call link.
    var onStartingSoon: ((Event) -> Void)?

    private var timer: Timer?
    private var reminderTimers: [String: Timer] = [:]
    private var reminded: Set<String> = []
    private let queue = DispatchQueue(label: "com.muckstack.granolaisdead.calendar", qos: .utility)

    func start() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        NotificationCenter.default.addObserver(forName: .gidPermissionsChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        authorized = Permissions.calendarGranted
        guard authorized else { upcoming = []; return }
        queue.async {
            let events = Self.load()
            Task { @MainActor in
                self.upcoming = events
                self.scheduleReminders()
            }
        }
    }

    func event(id: String?) -> Event? { upcoming.first { $0.id == id } }

    private nonisolated static func load() -> [Event] {
        let store = EKEventStore()
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 8, to: start)!
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: pred)
            .filter { !$0.isAllDay && $0.endDate > Date().addingTimeInterval(-3600) && $0.status != .canceled }
            .filter { ev in
                // Skip events the user declined.
                !(ev.attendees ?? []).contains { $0.isCurrentUser && $0.participantStatus == .declined }
            }
            .sorted { $0.startDate < $1.startDate }
            .prefix(40)
            .map { ev in
                let people: [Attendee] = (ev.attendees ?? []).filter { !$0.isCurrentUser && $0.participantType != .room }.map { p in
                    let email = p.url.absoluteString.hasPrefix("mailto:") ? String(p.url.absoluteString.dropFirst(7)) : nil
                    let name = p.name.flatMap { $0.contains("@") ? nil : $0 } ?? email.map { prettify($0) } ?? "Guest"
                    return Attendee(name: name, email: email)
                }
                return Event(id: ev.calendarItemIdentifier + "|" + String(Int(ev.startDate.timeIntervalSince1970)),
                             title: ev.title?.isEmpty == false ? ev.title! : "Untitled event",
                             start: ev.startDate, end: ev.endDate, attendees: people,
                             joinURL: joinLink(ev), calendarColor: ev.calendar.map { NSColor(cgColor: $0.cgColor) } ?? nil)
            }
    }

    nonisolated static func prettify(_ email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? email
        return local.split { $0 == "." || $0 == "_" || $0 == "-" }.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    nonisolated static func joinLink(_ ev: EKEvent) -> URL? {
        let hay = [ev.url?.absoluteString, ev.location, ev.notes].compactMap { $0 }.joined(separator: " ")
        let patterns = [#"https://[\w.-]*zoom\.us/[^\s<>"]+"#, #"https://meet\.google\.com/[a-z\-]+"#,
                        #"https://teams\.microsoft\.com/l/meetup-join/[^\s<>"]+"#, #"https://[\w.-]*webex\.com/[^\s<>"]+"#,
                        #"https://facetime\.apple\.com/[^\s<>"]+"#]
        for p in patterns {
            if let r = hay.range(of: p, options: .regularExpression) { return URL(string: String(hay[r])) }
        }
        return nil
    }

    private func scheduleReminders() {
        for t in reminderTimers.values { t.invalidate() }
        reminderTimers = [:]
        let now = Date()
        for ev in upcoming where ev.start > now && ev.start < now.addingTimeInterval(6 * 3600)
            && !reminded.contains(ev.id) && (!ev.attendees.isEmpty || ev.joinURL != nil) {
            let fire = max(now.addingTimeInterval(1), ev.start.addingTimeInterval(-60))
            let t = Timer(fire: fire, interval: 0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, !self.reminded.contains(ev.id) else { return }
                    self.reminded.insert(ev.id)
                    self.onStartingSoon?(ev)
                }
            }
            RunLoop.main.add(t, forMode: .common)
            reminderTimers[ev.id] = t
        }
    }
}
