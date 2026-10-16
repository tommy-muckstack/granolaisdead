import SwiftUI

/// One note: title, chips (My notes / Enhanced, date + people, folder), the
/// editor or enhanced notes, and the bottom dock (record + transcript, Ask).
struct NoteView: View {
    let noteID: UUID
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var recorder: MeetingRecorder
    @State private var panel: Panel = .none
    @State private var focusSegment: UUID?

    enum Panel { case none, transcript, chat }

    var body: some View {
        if let note = store.note(noteID) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TitleField(note: note)
                        ChipsRow(note: note).padding(.top, 14).padding(.bottom, 26)
                        if model.isShowingEnhanced(note) {
                            if model.enhancing.contains(note.id) {
                                GeneratingView()
                            } else if let e = note.enhanced {
                                EnhancedNotesView(note: note, notes: e) { seg in focusSegment = seg; panel = .transcript }
                            } else {
                                GeneratePrompt(note: note)
                            }
                        } else {
                            MyNotesEditor(note: note)
                                .frame(minHeight: 360, alignment: .top)
                        }
                        Color.clear.frame(height: 170)
                    }
                    .frame(maxWidth: 672, alignment: .leading)
                    .padding(.horizontal, 48)
                    .padding(.top, 64)
                    .frame(maxWidth: .infinity)
                }
                LinearGradient(colors: [G.Colors.background.opacity(0), G.Colors.background], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150).allowsHitTesting(false)
                NoteDock(note: note, panel: $panel, focusSegment: $focusSegment)
                    .frame(maxWidth: 820)
                    .padding(.horizontal, 32).padding(.bottom, 10)
            }
            .overlay(alignment: .topTrailing) { NoteMenu(note: note).padding(.top, 11).padding(.trailing, 14) }
            .onAppear {
                if recorder.noteID == note.id, note.myNotes.isEmpty { model.showEnhanced[note.id] = false }
                if let p = model.debugPanel { panel = p == "chat" ? .chat : .transcript; model.debugPanel = nil }
            }
        } else {
            Text("This note was deleted.").foregroundStyle(G.Colors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct TitleField: View {
    let note: Note
    @EnvironmentObject var store: NoteStore
    @State private var text = ""

    var body: some View {
        TextField("New note", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(G.Fonts.serif(32))
            .lineLimit(1...3)
            .onAppear { text = note.title }
            .onChange(of: text) { _, v in store.update(note.id) { $0.title = v } }
            .onChange(of: note.title) { _, v in if v != text { text = v } }
    }
}

private struct ChipsRow: View {
    let note: Note
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: NoteStore
    @State private var showPeople = false

    var body: some View {
        HStack(spacing: 10) {
            // [≡ My notes | ✨ Enhanced ▾]
            HStack(spacing: 0) {
                segment(selected: !model.isShowingEnhanced(note)) {
                    HStack(spacing: 6) { Image(systemName: "text.alignleft"); if !model.isShowingEnhanced(note) { Text("My notes") } }
                } action: { model.showEnhanced[note.id] = false }
                Menu {
                    Button { model.showEnhanced[note.id] = true; if note.enhanced == nil { model.enhance(note.id) } } label: {
                        Label("Enhanced notes", systemImage: "sparkles")
                    }
                    Button { model.enhance(note.id) } label: { Label("Regenerate", systemImage: "arrow.clockwise") }
                        .disabled(note.enhanced == nil)
                    Divider()
                    Section("Templates") {
                        ForEach(NoteTemplate.all) { t in
                            Button { model.enhance(note.id, template: t.id) } label: {
                                Text("\(t.symbol)  \(t.name)\(note.templateID == t.id ? "  ✓" : "")")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        if model.isShowingEnhanced(note) { Text("Enhanced") }
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .font(G.Fonts.ui(14, .medium))
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Capsule().fill(model.isShowingEnhanced(note) ? G.Colors.surfaceRaised : .clear))
                    .contentShape(Capsule())
                } primaryAction: {
                    model.showEnhanced[note.id] = true
                    if note.enhanced == nil { model.enhance(note.id) }
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            }
            .padding(2)
            .overlay(Capsule().strokeBorder(G.Colors.border))

            Button { showPeople.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text((note.startedAt ?? note.createdAt).formatted(.dateTime.month(.abbreviated).day()))
                    Image(systemName: "person.2").padding(.leading, 6)
                    Text(note.attendees.isEmpty ? "Me" : "\(note.attendees.count + 1)")
                }
                .font(G.Fonts.ui(14, .medium))
                .padding(.horizontal, 12).frame(height: 36)
                .overlay(Capsule().strokeBorder(G.Colors.border))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPeople, arrowEdge: .bottom) { PeoplePopover(note: note) }

            Menu {
                ForEach(store.folders) { f in
                    Button("\(f.name)\(note.folderID == f.id ? "  ✓" : "")") { store.update(note.id) { $0.folderID = f.id } }
                }
                if note.folderID != nil { Divider(); Button("Remove from folder") { store.update(note.id) { $0.folderID = nil } } }
                Divider()
                Button("New folder…") { let f = store.createFolder("New folder"); store.update(note.id) { $0.folderID = f.id } }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: note.folderID == nil ? "folder.badge.plus" : "folder.fill")
                    Text(store.folders.first { $0.id == note.folderID }?.name ?? "Add to folder")
                }
                .font(G.Fonts.ui(14, .medium))
                .padding(.horizontal, 12).frame(height: 36)
                .overlay(Capsule().strokeBorder(G.Colors.border))
                .contentShape(Capsule())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        }
        .foregroundStyle(G.Colors.textPrimary)
    }

    private func segment<L: View>(selected: Bool, @ViewBuilder label: () -> L, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label().font(G.Fonts.ui(14, .medium))
                .padding(.horizontal, 12).frame(height: 32)
                .background(Capsule().fill(selected ? G.Colors.surfaceRaised : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PeoplePopover: View {
    let note: Note
    @EnvironmentObject var store: NoteStore
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text((note.startedAt ?? note.createdAt).formatted(date: .complete, time: .shortened))
                .font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary)
            if let d = note.durationSeconds, note.startedAt != nil {
                Text("Recorded \(Int(d / 60)) min").font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary)
            }
            Divider()
            row(Attendee(name: "Me"), removable: false)
            ForEach(note.attendees, id: \.self) { a in row(a, removable: true) }
            TextField("Add person", text: $newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let n = newName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    store.update(note.id) { $0.attendees.append(Attendee(name: n)) }
                    newName = ""
                }
        }
        .padding(14).frame(width: 280)
    }

    private func row(_ a: Attendee, removable: Bool) -> some View {
        HStack(spacing: 10) {
            Text(a.initials).font(G.Fonts.ui(11, .semibold)).frame(width: 26, height: 26).background(Circle().fill(G.Colors.tile))
            VStack(alignment: .leading, spacing: 0) {
                Text(a.name).font(G.Fonts.ui(13.5))
                if let e = a.email { Text(e).font(G.Fonts.ui(11.5)).foregroundStyle(G.Colors.textSecondary) }
            }
            Spacer()
            if removable {
                Button { store.update(note.id) { $0.attendees.removeAll { $0 == a } } } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundStyle(G.Colors.textTertiary).help("Remove")
            }
        }
    }
}

private struct MyNotesEditor: View {
    let note: Note
    @EnvironmentObject var store: NoteStore
    @State private var text = ""

    var body: some View {
        PlainTextEditor(text: $text, placeholder: "Write notes… GranolaIsDead fills in the rest from the transcript.",
                        autofocus: note.myNotes.isEmpty)
            .onAppear { text = note.myNotes }
            .onChange(of: text) { _, v in store.update(note.id) { $0.myNotes = v } }
    }
}

private struct GeneratingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Writing your notes…").font(G.Fonts.ui(15)).foregroundStyle(G.Colors.textSecondary)
        }
        .padding(.top, 8)
    }
}

private struct GeneratePrompt: View {
    let note: Note
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var recorder: MeetingRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note.hasTranscript ? "Turn the transcript and your notes into clean meeting notes."
                 : recorder.noteID == note.id ? "Recording. Notes are written when you stop."
                 : "Start recording, or jot notes, then generate.")
                .font(G.Fonts.ui(15)).foregroundStyle(G.Colors.textSecondary)
            if recorder.noteID != note.id {
                HStack(spacing: 8) {
                    PillButton { Label("Generate notes", systemImage: "sparkles") } action: { model.enhance(note.id) }
                    if !note.hasTranscript { PillButton { Label("Start recording", systemImage: "waveform") } action: { model.startRecording(note.id) } }
                }
            }
        }
        .padding(.top, 4)
    }
}

/// Granola's enhanced notes: "#" headings hung in the margin, dot bullets,
/// hollow sub-bullets, your own lines in full ink and generated lines gray.
struct EnhancedNotesView: View {
    let note: Note
    let notes: EnhancedNotes
    var showInTranscript: (UUID) -> Void
    @EnvironmentObject var store: NoteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(notes.sections) { s in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("#").font(G.Fonts.ui(17, .semibold)).foregroundStyle(G.Colors.textTertiary).frame(width: 22, alignment: .leading).padding(.leading, -22)
                        Text(s.heading).font(G.Fonts.ui(17, .semibold))
                    }
                    .padding(.bottom, 4)
                    ForEach(s.lines) { l in
                        LineRow(line: l, toggle: { toggle(s.id, l.id) }, locate: locate(l))
                    }
                }
            }
            HStack(spacing: 6) {
                Image(systemName: engineSymbol).font(.system(size: 11))
                Text(engineLabel).font(G.Fonts.ui(12))
            }
            .foregroundStyle(G.Colors.textTertiary)
        }
        .textSelection(.enabled)
    }

    private var engineSymbol: String { notes.engine == "basic" ? "text.quote" : notes.engine == "on-device" ? "lock" : "key" }
    private var engineLabel: String {
        switch notes.engine {
        case "on-device": return "Written on this Mac by Apple's on-device model"
        case "basic": return "Basic notes (pulled from the transcript). Turn on Apple Intelligence or add an API key in Settings → AI for written notes."
        default: return "Written with your own \(notes.engine.hasPrefix("claude") ? "Claude" : "OpenAI") key"
        }
    }

    private func toggle(_ section: UUID, _ line: UUID) {
        store.update(note.id) { n in
            guard var e = n.enhanced, let si = e.sections.firstIndex(where: { $0.id == section }),
                  let li = e.sections[si].lines.firstIndex(where: { $0.id == line }) else { return }
            e.sections[si].lines[li].done = !(e.sections[si].lines[li].done ?? false)
            n.enhanced = e
        }
    }

    /// The transcript segment that best supports a generated line.
    private func locate(_ l: EnhancedNotes.Line) -> (() -> Void)? {
        guard !note.transcript.isEmpty else { return nil }
        let w = Set(BasicEnhancer.content(l.text))
        guard w.count >= 2 else { return nil }
        let best = note.transcript.max { Set(BasicEnhancer.content($0.text)).intersection(w).count < Set(BasicEnhancer.content($1.text)).intersection(w).count }
        guard let best, Set(BasicEnhancer.content(best.text)).intersection(w).count >= 2 else { return nil }
        return { showInTranscript(best.id) }
    }
}

private struct LineRow: View {
    let line: EnhancedNotes.Line
    let toggle: () -> Void
    let locate: (() -> Void)?
    @State private var hover = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let done = line.done {
                Button(action: toggle) {
                    Image(systemName: done ? "checkmark.square.fill" : "square").font(.system(size: 14))
                        .foregroundStyle(done ? G.Colors.accent : G.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .strokeBorder(G.Colors.textTertiary, lineWidth: line.level > 0 ? 1.2 : 0)
                    .background(Circle().fill(line.level > 0 ? .clear : G.Colors.textTertiary))
                    .frame(width: 6, height: 6).offset(y: -2)
            }
            Text(line.text)
                .font(G.Fonts.ui(16))
                .lineSpacing(4)
                .foregroundStyle(line.mine ? G.Colors.textPrimary : G.Colors.generated)
                .strikethrough(line.done == true, color: G.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if hover, let locate {
                Button(action: locate) { Image(systemName: "text.magnifyingglass").font(.system(size: 13)) }
                    .buttonStyle(.plain).foregroundStyle(G.Colors.textSecondary).help("Show in transcript")
            }
        }
        .padding(.leading, CGFloat(line.level) * 26 + 6)
        .padding(.vertical, 3).padding(.trailing, 8)
        .background(RoundedRectangle(cornerRadius: G.Radius.md).fill(hover ? G.Colors.surface : .clear).padding(.leading, CGFloat(line.level) * 26))
        .onHover { hover = $0 }
    }
}

private struct NoteMenu: View {
    let note: Note
    @EnvironmentObject var model: AppModel
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button("Copy notes") { copyNotes() }
                Button("Copy transcript") { copyToPasteboard(note.transcriptTextWithTimes) }.disabled(!note.hasTranscript)
                Button("Export as Markdown…") { export() }
                Divider()
                Button("Regenerate notes") { model.enhance(note.id) }
                Divider()
                Button("Delete note", role: .destructive) { model.delete(note.id) }
            } label: { Image(systemName: "ellipsis").font(.system(size: 14)).frame(width: 30, height: 30).contentShape(Rectangle()) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("More")

            Button { copyNotes() } label: {
                HStack(spacing: 6) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied" : "Copy")
                }
                .font(G.Fonts.ui(14, .medium))
                .foregroundStyle(G.Colors.onButton)
                .padding(.horizontal, 14).frame(height: 32)
                .background(Capsule().fill(G.Colors.button))
            }
            .buttonStyle(.plain)
            .help("Copy notes as Markdown, ready to paste into email or Slack")
        }
    }

    private var markdown: String {
        var s = "# \(note.displayTitle)\n\n"
        if let e = note.enhanced { s += e.markdown } else { s += note.myNotes + "\n" }
        return s
    }

    private func copyNotes() {
        copyToPasteboard(markdown)
        copied = true
        Analytics.track("app_notes_copied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
    }

    private func export() {
        let p = NSSavePanel()
        p.nameFieldStringValue = note.displayTitle.replacingOccurrences(of: "/", with: "-") + ".md"
        p.allowedContentTypes = [.init(filenameExtension: "md")!]
        guard p.runModal() == .OK, let url = p.url else { return }
        var s = markdown
        if note.hasTranscript { s += "\n## Transcript\n\n" + note.transcriptTextWithTimes + "\n" }
        try? s.write(to: url, atomically: true, encoding: .utf8)
    }
}
