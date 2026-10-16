import SwiftUI

/// The floating "Ask anything" pill. `onAsk` gets the trimmed question.
struct AskBar: View {
    var placeholder: String
    var suggestion: String?
    var leading: AnyView? = nil
    let onAsk: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let leading { leading }
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(G.Fonts.ui(16))
                    .focused($focused)
                    .onSubmit(send)
                if !text.isEmpty {
                    Button(action: send) {
                        Image(systemName: "arrow.up").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(G.Colors.onButton).frame(width: 30, height: 30)
                            .background(Circle().fill(G.Colors.button))
                    }
                    .buttonStyle(.plain).help("Ask")
                } else if let suggestion {
                    SuggestionChip(title: suggestion) { onAsk(suggestion) }
                }
            }
            .padding(.leading, 22).padding(.trailing, 8)
            .frame(height: 54)
            .background(Capsule().fill(G.Colors.surface))
            .overlay(Capsule().strokeBorder(G.Colors.border.opacity(0.8)))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        }
    }

    private func send() {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        text = ""
        onAsk(q)
    }
}

/// Bottom of a note: record/transcript button + Ask bar, and the panel that
/// opens above them (live transcript, or the chat about this meeting).
struct NoteDock: View {
    let note: Note
    @Binding var panel: NoteView.Panel
    @Binding var focusSegment: UUID?
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var recorder: MeetingRecorder
    @EnvironmentObject var speech: SpeechModel
    @State private var asking = false

    private var isRecording: Bool { recorder.noteID == note.id }
    /// Granola's action pill: after transcription stops, with a transcript and no notes yet.
    private var showGeneratePill: Bool {
        !isRecording && note.hasTranscript && note.enhanced == nil && !model.enhancing.contains(note.id) && !recorder.finishing.contains(note.id)
    }

    var body: some View {
        VStack(spacing: 6) {
            switch panel {
            case .transcript:
                TranscriptPanel(note: note, focusSegment: $focusSegment) { panel = .none }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .chat:
                ChatPanel(note: note, asking: asking) { panel = .none }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .none:
                EmptyView()
            }
            if panel == .none, showGeneratePill {
                SuggestionChip(title: note.myNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Generate notes" : "Enhance notes", symbol: "sparkles") {
                    model.enhance(note.id)
                }
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if panel != .transcript {
                AskBar(placeholder: "Ask anything", suggestion: note.hasTranscript ? "Write follow up email" : nil,
                       leading: AnyView(recordButton)) { q in ask(q) }
            }
            Text("GranolaIsDead uses AI and can make mistakes.")
                .font(G.Fonts.ui(11.5)).foregroundStyle(G.Colors.textTertiary)
        }
        .animation(G.Motion.gentle, value: panel)
    }

    private var recordButton: some View {
        Button { panel = panel == .transcript ? .none : .transcript; if !isRecording && !note.hasTranscript { model.startRecording(note.id) } } label: {
            HStack(spacing: 4) {
                Waveform(level: isRecording ? max(recorder.micLevel, recorder.systemLevel) : 0,
                         active: isRecording && !recorder.isPaused,
                         color: isRecording ? G.Colors.accent : G.Colors.textPrimary)
                Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold)).foregroundStyle(G.Colors.textSecondary)
            }
            .frame(width: 62, height: 54)
            .background(Circle().fill(G.Colors.surface).frame(width: 62, height: 54).clipShape(Capsule()))
            .overlay(Capsule().strokeBorder(isRecording ? G.Colors.accent.opacity(0.6) : G.Colors.border.opacity(0.8)))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Show transcript" : note.hasTranscript ? "Show transcript" : "Start transcribing")
    }

    private func ask(_ q: String) {
        let question = q == "Write follow up email"
            ? "Write a short, friendly follow-up email to the other attendees summarizing what we agreed and the next steps."
            : q
        panel = .chat
        asking = true
        model.store.update(note.id, immediately: true) { $0.chat.append(ChatMessage(role: .user, text: q)) }
        Task {
            let history = model.store.note(note.id)?.chat.dropLast() ?? []
            let current = model.store.note(note.id) ?? note
            let a = await NoteEngine.answer(question, note: current, history: Array(history))
            model.store.update(note.id, immediately: true) { $0.chat.append(ChatMessage(role: .assistant, text: a)) }
            asking = false
            Analytics.track("app_chat_asked", ["scope": "note"])
        }
    }
}

struct TranscriptPanel: View {
    let note: Note
    @Binding var focusSegment: UUID?
    let close: () -> Void
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var recorder: MeetingRecorder
    @EnvironmentObject var speech: SpeechModel
    @State private var query = ""
    @State private var copied = false

    private var isRecording: Bool { recorder.noteID == note.id }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(G.Colors.textSecondary)
                TextField("Search transcript", text: $query).textFieldStyle(.plain).font(G.Fonts.ui(14))
                Spacer()
                IconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copy transcript") {
                    copyToPasteboard(note.transcriptTextWithTimes); copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }
                .disabled(!note.hasTranscript)
                IconButton(symbol: "minus", help: "Hide transcript", action: close)
            }
            .padding(.horizontal, 18).frame(height: 50)
            Divider().overlay(G.Colors.border)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if note.transcript.isEmpty {
                            emptyState.padding(.top, 30)
                        }
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, seg in
                            let prev = i > 0 ? filtered[i - 1] : nil
                            Bubble(seg: seg, showName: seg.source == .system && prev?.source != .system,
                                   name: theirName, highlighted: seg.id == focusSegment)
                                .id(seg.id)
                        }
                        Color.clear.frame(height: 4).id("bottom")
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                }
                .onAppear {
                    if let f = focusSegment { proxy.scrollTo(f, anchor: .center) } else { proxy.scrollTo("bottom") }
                }
                .onChange(of: note.transcript.count) { _, _ in
                    if focusSegment == nil, query.isEmpty { withAnimation { proxy.scrollTo("bottom") } }
                }
                .onChange(of: focusSegment) { _, f in if let f { withAnimation { proxy.scrollTo(f, anchor: .center) } } }
            }

            Divider().overlay(G.Colors.border)
            HStack(spacing: 12) {
                Button { model.toggleRecording(note.id) } label: {
                    HStack(spacing: 6) {
                        Waveform(level: max(recorder.micLevel, recorder.systemLevel), active: isRecording && !recorder.isPaused,
                                 color: isRecording ? G.Colors.accent : G.Colors.textPrimary)
                    }
                    .frame(width: 44, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12).fill(G.Colors.surfaceRaised))
                }
                .buttonStyle(.plain).help(isRecording ? "Stop" : "Resume")

                if isRecording {
                    Button { recorder.togglePause() } label: {
                        Text(recorder.isPaused ? "Resume" : "Pause").font(G.Fonts.ui(15, .medium)).foregroundStyle(G.Colors.accent)
                    }.buttonStyle(.plain)
                    Button { model.stopRecording() } label: {
                        Text("Stop").font(G.Fonts.ui(15, .medium)).foregroundStyle(G.Colors.textPrimary)
                    }.buttonStyle(.plain)
                    Text(Note.stamp(recorder.elapsed)).font(G.Fonts.ui(13).monospacedDigit()).foregroundStyle(G.Colors.textSecondary)
                } else {
                    Button { model.startRecording(note.id) } label: {
                        Text(note.hasTranscript ? "Resume" : "Start transcribing").font(G.Fonts.ui(15, .medium)).foregroundStyle(G.Colors.accent)
                    }.buttonStyle(.plain)
                }
                Spacer()
                statusLine
            }
            .padding(.horizontal, 14).frame(height: 58)
        }
        .frame(height: 460)
        .background(RoundedRectangle(cornerRadius: 26).fill(G.Colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(G.Colors.border.opacity(0.8)))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
    }

    @ViewBuilder private var statusLine: some View {
        if case .downloading(let p) = speech.state {
            Text("Downloading speech model… \(Int(p * 100))%").font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary)
        } else if speech.state == .failed {
            Button("Speech model failed to load. Retry") { speech.prepare() }.buttonStyle(.plain).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.recording)
        } else if isRecording && !recorder.systemAudioAvailable {
            Button("Only your mic is recording. Allow system audio") { Permissions.openPrivacy(.systemAudio) }
                .buttonStyle(.plain).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary)
        } else if recorder.finishing.contains(note.id) {
            HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Finishing transcript…").font(G.Fonts.ui(12.5)) }.foregroundStyle(G.Colors.textSecondary)
        } else if !isRecording, note.hasTranscript, note.enhanced == nil, !model.enhancing.contains(note.id) {
            SuggestionChip(title: "Generate notes", symbol: "sparkles") { model.enhance(note.id) }
        } else {
            HStack(spacing: 5) { Image(systemName: "lock.fill").font(.system(size: 10)); Text("Transcribed on this Mac").font(G.Fonts.ui(12.5)) }
                .foregroundStyle(G.Colors.textTertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: isRecording ? "waveform" : "text.bubble").font(.system(size: 22)).foregroundStyle(G.Colors.textTertiary)
            Text(isRecording ? "Listening… the transcript appears as people talk." : "No transcript yet.")
                .font(G.Fonts.ui(14)).foregroundStyle(G.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var filtered: [TranscriptSegment] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? note.transcript : note.transcript.filter { $0.text.lowercased().contains(q) }
    }

    private var theirName: String {
        note.attendees.count == 1 ? note.attendees[0].name : "Them"
    }
}

private struct Bubble: View {
    let seg: TranscriptSegment
    let showName: Bool
    let name: String
    let highlighted: Bool

    var body: some View {
        VStack(alignment: seg.source == .mic ? .trailing : .leading, spacing: 4) {
            if showName { Text(name).font(G.Fonts.ui(13, .medium)).foregroundStyle(G.Colors.textSecondary).padding(.top, 8).padding(.leading, 6) }
            Text(seg.text)
                .font(G.Fonts.ui(15))
                .textSelection(.enabled)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(seg.source == .mic ? G.Colors.meBubble : G.Colors.themBubble))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(highlighted ? G.Colors.accent : .clear, lineWidth: 1.5))
                .help(Note.stamp(seg.start))
        }
        .frame(maxWidth: .infinity, alignment: seg.source == .mic ? .trailing : .leading)
        .padding(seg.source == .mic ? .leading : .trailing, 70)
    }
}

struct ChatPanel: View {
    let note: Note
    let asking: Bool
    let close: () -> Void
    @EnvironmentObject var store: NoteStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ask about this meeting").font(G.Fonts.ui(13.5, .medium)).foregroundStyle(G.Colors.textSecondary)
                Spacer()
                IconButton(symbol: "trash", help: "Clear chat") { store.update(note.id) { $0.chat = [] }; close() }
                IconButton(symbol: "minus", help: "Hide", action: close)
            }
            .padding(.horizontal, 18).frame(height: 46)
            Divider().overlay(G.Colors.border)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(note.chat) { m in ChatBubble(message: m) }
                        if asking { HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Thinking…").foregroundStyle(G.Colors.textSecondary) } }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(18)
                }
                .onAppear { proxy.scrollTo("end") }
                .onChange(of: note.chat.count) { _, _ in withAnimation { proxy.scrollTo("end") } }
            }
        }
        .frame(maxHeight: 380)
        .background(RoundedRectangle(cornerRadius: 22).fill(G.Colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(G.Colors.border.opacity(0.8)))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    @State private var copied = false

    var body: some View {
        if message.role == .user {
            Text(message.text).font(G.Fonts.ui(15))
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(G.Colors.surfaceRaised))
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(displayMarkdown(message.text)).font(G.Fonts.ui(15)).lineSpacing(4).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button { copyToPasteboard(message.text); copied = true } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc").font(G.Fonts.ui(12))
                }
                .buttonStyle(.plain).foregroundStyle(G.Colors.textTertiary)
            }
        }
    }
}
