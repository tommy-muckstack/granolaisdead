import SwiftUI

/// "Coming up" calendar card + every note grouped by day + the Ask bar.
/// With a folder id it shows just that folder.
struct HomeView: View {
    let folder: UUID?
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var calendar: CalendarStore
    @State private var dayOffset = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let folder, let f = store.folders.first(where: { $0.id == folder }) {
                        Text(f.name).font(G.Fonts.serif(32)).padding(.bottom, 24)
                    } else {
                        HStack {
                            Text("Coming up").font(G.Fonts.serif(32))
                            Spacer()
                            if calendar.authorized {
                                IconButton(symbol: "chevron.left", help: "Earlier") { dayOffset = max(0, dayOffset - 1) }.disabled(dayOffset == 0)
                                IconButton(symbol: "chevron.right", help: "Later") { dayOffset = min(6, dayOffset + 1) }
                            }
                        }
                        .padding(.bottom, 16)
                        ComingUpCard(dayOffset: dayOffset).padding(.bottom, 36)
                    }
                    NotesList(notes: notes)
                    Color.clear.frame(height: 120)
                }
                .frame(maxWidth: 672)
                .padding(.horizontal, 40)
                .padding(.top, 64)
                .frame(maxWidth: .infinity)
            }
            LinearGradient(colors: [G.Colors.background.opacity(0), G.Colors.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 120).allowsHitTesting(false)
            AskBar(placeholder: "Ask anything", suggestion: "List recent todos") { q in
                model.pendingQuestion = q
                model.go(.chat)
            }
            .frame(maxWidth: 800)
            .padding(.horizontal, 32).padding(.bottom, 26)
        }
    }

    private var notes: [Note] {
        folder.map { id in store.notes.filter { $0.folderID == id } } ?? store.notes
    }
}

struct ComingUpCard: View {
    let dayOffset: Int
    @EnvironmentObject var calendar: CalendarStore
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if !calendar.authorized {
                HStack(spacing: 16) {
                    Image(systemName: "calendar").font(.system(size: 22)).foregroundStyle(G.Colors.textSecondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("See your upcoming meetings").font(G.Fonts.ui(15, .medium))
                        Text("Uses the calendars already in macOS Calendar: Google, Outlook, iCloud.")
                            .font(G.Fonts.ui(13)).foregroundStyle(G.Colors.textSecondary)
                    }
                    Spacer()
                    PillButton { Text("Connect calendar") } action: {
                        Task {
                            if Permissions.calendarDecided && !Permissions.calendarGranted { Permissions.openPrivacy(.calendar) }
                            else { _ = await Permissions.requestCalendar() }
                            calendar.refresh()
                        }
                    }
                }
                .padding(22)
            } else {
                let days = visibleDays
                ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                    if i > 0 { DashedDivider() }
                    DayRow(day: day, events: events(on: day))
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(G.Colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(G.Colors.border.opacity(0.7)))
    }

    private var visibleDays: [Date] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: Date()))!
        // Today plus the next day that has events (Granola shows two days).
        var days = [start]
        for k in 1...7 {
            let d = cal.date(byAdding: .day, value: k, to: start)!
            if !events(on: d).isEmpty || k == 7 { days.append(d); break }
        }
        return days
    }

    private func events(on day: Date) -> [CalendarStore.Event] {
        calendar.upcoming.filter { Calendar.current.isDate($0.start, inSameDayAs: day) && (Calendar.current.isDateInToday(day) ? $0.end > Date() : true) }
    }
}

private struct DayRow: View {
    let day: Date
    let events: [CalendarStore.Event]
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: NoteStore

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(day.formatted(.dateTime.day())).font(G.Fonts.serif(36))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(day.formatted(.dateTime.month(.wide))).font(G.Fonts.ui(13.5, .medium))
                        if Calendar.current.isDateInToday(day) { Circle().fill(Color.orange).frame(width: 5, height: 5) }
                    }
                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(G.Fonts.ui(13.5)).foregroundStyle(G.Colors.textSecondary)
                }
            }
            .frame(width: 200, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                if events.isEmpty {
                    EventLine(title: Calendar.current.isDateInToday(day) ? "No more events today" : "No events", time: nil, muted: true, color: nil) {}
                } else {
                    ForEach(events) { ev in
                        EventLine(title: ev.title, time: timeRange(ev), muted: false, color: ev.calendarColor,
                                  hasNote: store.notes.contains { $0.calendarEventID == ev.id }) {
                            model.newNote(record: false, event: ev)
                        }
                        .contextMenu {
                            Button("Open notes") { model.newNote(event: ev) }
                            Button("Start recording") { model.newNote(record: true, event: ev) }
                            if let url = ev.joinURL { Button("Join call") { NSWorkspace.shared.open(url) } }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 26).padding(.vertical, 20)
    }

    private func timeRange(_ ev: CalendarStore.Event) -> String {
        "\(ev.start.formatted(date: .omitted, time: .shortened)) – \(ev.end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct EventLine: View {
    let title: String
    let time: String?
    let muted: Bool
    let color: NSColor?
    var hasNote = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2).fill(color.map { Color(nsColor: $0) } ?? G.Colors.textTertiary).frame(width: 3, height: time == nil ? 22 : 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(G.Fonts.ui(15)).foregroundStyle(muted ? G.Colors.textSecondary : G.Colors.textPrimary).lineLimit(1)
                        if hasNote { Image(systemName: "doc.text").font(.system(size: 11)).foregroundStyle(G.Colors.textTertiary) }
                    }
                    if let time { Text(time).font(G.Fonts.ui(13)).foregroundStyle(G.Colors.textSecondary) }
                }
                Spacer()
                if hover, !muted { Text("Open notes").font(G.Fonts.ui(12.5, .medium)).foregroundStyle(G.Colors.textSecondary) }
            }
            .padding(.vertical, 3).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: G.Radius.md).fill(hover && !muted ? G.Colors.surfaceHover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(muted)
        .onHover { hover = $0 }
    }
}

private struct DashedDivider: View {
    var body: some View {
        Rectangle().fill(.clear).frame(height: 1)
            .overlay(Line().stroke(G.Colors.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
    struct Line: Shape { func path(in r: CGRect) -> Path { Path { p in p.move(to: .init(x: 0, y: 0.5)); p.addLine(to: .init(x: r.width, y: 0.5)) } } }
}

struct NotesList: View {
    let notes: [Note]
    @EnvironmentObject var model: AppModel

    var body: some View {
        if notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("No notes yet").font(G.Fonts.ui(15, .medium))
                Text("Start a note when your next meeting begins. GranolaIsDead transcribes your computer audio and mic, so no bot joins the call.")
                    .font(G.Fonts.ui(13.5)).foregroundStyle(G.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    PillButton { Label("New note", systemImage: "plus") } action: { model.newNote() }
                    PillButton { Label("Start recording", systemImage: "waveform") } action: { model.newNote(record: true) }
                }
                .padding(.top, 6)
            }
            .padding(.top, 4)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groups, id: \.0) { day, items in
                    Text(day.dayHeader).font(G.Fonts.ui(13.5, .medium)).foregroundStyle(G.Colors.textSecondary)
                        .padding(.top, 20).padding(.bottom, 6).padding(.leading, 12)
                    ForEach(items) { NoteRow(note: $0) }
                }
            }
        }
    }

    private var groups: [(Date, [Note])] {
        let cal = Calendar.current
        let d = Dictionary(grouping: notes) { cal.startOfDay(for: $0.sortDate) }
        return d.keys.sorted(by: >).map { ($0, d[$0]!.sorted { $0.sortDate > $1.sortDate }) }
    }
}

struct NoteRow: View {
    let note: Note
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var recorder: MeetingRecorder
    @State private var hover = false

    var body: some View {
        Button { model.go(.note(note.id)) } label: {
            HStack(spacing: 14) {
                NoteTile(note: note)
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle).font(G.Fonts.ui(15)).lineLimit(1)
                    Text(subtitle).font(G.Fonts.ui(13)).foregroundStyle(G.Colors.textSecondary).lineLimit(1)
                }
                Spacer()
                if recorder.noteID == note.id {
                    HStack(spacing: 6) { Waveform(level: max(recorder.micLevel, recorder.systemLevel), active: true, color: G.Colors.accent); Text("Recording").font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.accent) }
                } else if model.enhancing.contains(note.id) {
                    ProgressView().controlSize(.small)
                }
                if note.folderID != nil { Image(systemName: "folder.fill").font(.system(size: 12)).foregroundStyle(G.Colors.textSecondary) }
                if hover {
                    Menu {
                        folderMenu
                        Divider()
                        Button("Delete note", role: .destructive) { model.delete(note.id) }
                    } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                } else {
                    Text(note.sortDate.shortTime).font(G.Fonts.ui(13)).foregroundStyle(G.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: G.Radius.lg).fill(hover ? G.Colors.surface : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .contextMenu {
            folderMenu
            Divider()
            Button("Delete note", role: .destructive) { model.delete(note.id) }
        }
    }

    @ViewBuilder private var folderMenu: some View {
        Menu("Move to folder") {
            ForEach(store.folders) { f in Button(f.name) { store.update(note.id) { $0.folderID = f.id } } }
            if note.folderID != nil { Divider(); Button("Remove from folder") { store.update(note.id) { $0.folderID = nil } } }
            Divider()
            Button("New folder…") { let f = store.createFolder("New folder"); store.update(note.id) { $0.folderID = f.id } }
        }
    }

    private var subtitle: String {
        note.attendees.isEmpty ? "Me" : note.attendees.map { $0.name.split(separator: " ").first.map(String.init) ?? $0.name }.joined(separator: ", ")
    }
}
