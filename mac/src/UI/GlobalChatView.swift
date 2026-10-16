import SwiftUI

/// Chat across all meetings ("What action items do I have?"). Answers come
/// from the most relevant notes, picked locally by keyword overlap and
/// recency, then passed to the same engine as a per-note chat.
struct GlobalChatView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: NoteStore
    @State private var thread: [ChatMessage] = []
    @State private var asking = false
    @State private var sources: [UUID] = []

    private let recipes = ["List recent todos", "Summarize my week", "What decisions did we make?", "Who do I owe a follow-up?"]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if thread.isEmpty {
                            Text("Ask anything").font(G.Fonts.serif(32)).padding(.top, 120)
                            Text("Questions are answered from your meeting notes on this Mac.")
                                .font(G.Fonts.ui(14)).foregroundStyle(G.Colors.textSecondary)
                            Text("Recipes").font(G.Fonts.ui(13.5, .medium)).foregroundStyle(G.Colors.textSecondary).padding(.top, 30)
                            FlowRow(spacing: 8) {
                                ForEach(recipes, id: \.self) { r in SuggestionChip(title: r) { ask(r) } }
                            }
                            if !store.notes.isEmpty {
                                Text("Recent notes").font(G.Fonts.ui(13.5, .medium)).foregroundStyle(G.Colors.textSecondary).padding(.top, 30)
                                ForEach(store.notes.prefix(4)) { NoteRow(note: $0) }
                            }
                        } else {
                            ForEach(thread) { ChatBubble(message: $0) }
                            if asking { HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Reading your notes…").foregroundStyle(G.Colors.textSecondary) } }
                            if !sources.isEmpty, !asking {
                                Text("From").font(G.Fonts.ui(12.5, .medium)).foregroundStyle(G.Colors.textTertiary)
                                ForEach(sources, id: \.self) { id in if let n = store.note(id) { NoteRow(note: n) } }
                            }
                        }
                        Color.clear.frame(height: 130).id("end")
                    }
                    .frame(maxWidth: 672, alignment: .leading)
                    .padding(.horizontal, 48).padding(.top, 64)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: thread.count) { _, _ in withAnimation { proxy.scrollTo("end") } }
            }
            HStack {
                AskBar(placeholder: thread.isEmpty ? "What action items do I have?" : "Ask a follow-up", suggestion: nil) { ask($0) }
                if !thread.isEmpty { IconButton(symbol: "arrow.counterclockwise", help: "New chat") { thread = []; sources = [] } }
            }
            .frame(maxWidth: 800).padding(.horizontal, 32).padding(.bottom, 26)
        }
        .onAppear { if let q = model.pendingQuestion { model.pendingQuestion = nil; ask(q) } }
    }

    private func ask(_ q: String) {
        guard !asking else { return }
        thread.append(ChatMessage(role: .user, text: q))
        asking = true
        let picked = Self.relevant(q, in: store.notes)
        sources = picked.map(\.id)
        let digest = Note(title: "Your meetings", myNotes: picked.map(Self.digest).joined(separator: "\n\n"))
        let history = Array(thread.dropLast())
        Task {
            let a = picked.isEmpty ? "You don’t have any notes yet. Record a meeting and ask again."
                : await NoteEngine.answer(q, note: digest, history: history)
            thread.append(ChatMessage(role: .assistant, text: a))
            asking = false
            Analytics.track("app_chat_asked", ["scope": "all"])
        }
    }

    static func relevant(_ q: String, in notes: [Note]) -> [Note] {
        let words = Set(BasicEnhancer.content(q))
        let recentFirst = notes.sorted { $0.sortDate > $1.sortDate }
        let scored = recentFirst.enumerated().map { (i, n) -> (Note, Double) in
            let hay = Set(BasicEnhancer.content(n.title + " " + (n.enhanced?.markdown ?? "") + " " + n.myNotes))
            let overlap = Double(hay.intersection(words).count)
            return (n, overlap * 2 + max(0, 6 - Double(i)) * 0.5)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(6).map(\.0)
    }

    static func digest(_ n: Note) -> String {
        let date = (n.startedAt ?? n.createdAt).formatted(date: .abbreviated, time: .shortened)
        var s = "=== \(n.displayTitle) (\(date))\(n.attendees.isEmpty ? "" : " with \(n.attendees.map(\.name).joined(separator: ", "))") ===\n"
        if let e = n.enhanced { s += e.markdown }
        else if !n.myNotes.isEmpty { s += n.myNotes + "\n" }
        if n.enhanced == nil, n.hasTranscript { s += String(n.transcriptText.prefix(1500)) + "\n" }
        return String(s.prefix(2500))
    }
}

/// Wrapping row of chips.
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > b.maxX, x > b.minX { x = b.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}

/// ⌘K: find a note by title, your notes, enhanced notes or transcript.
struct SearchOverlay: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: NoteStore
    @State private var q = ""
    @State private var selected = 0
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.25).ignoresSafeArea().onTapGesture { model.searchPresented = false }
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(G.Colors.textSecondary)
                    TextField("Search notes and transcripts", text: $q)
                        .textFieldStyle(.plain).font(G.Fonts.ui(17)).focused($focused)
                        .onSubmit { open(selected) }
                        .onKeyPress(.downArrow) { selected = min(selected + 1, max(0, results.count - 1)); return .handled }
                        .onKeyPress(.upArrow) { selected = max(0, selected - 1); return .handled }
                        .onKeyPress(.escape) { model.searchPresented = false; return .handled }
                }
                .padding(.horizontal, 18).frame(height: 56)
                Divider().overlay(G.Colors.border)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(results.prefix(30).enumerated()), id: \.element.0.id) { i, r in
                            Button { open(i) } label: {
                                HStack(spacing: 12) {
                                    NoteTile(note: r.0)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.0.displayTitle).font(G.Fonts.ui(14.5)).lineLimit(1)
                                        Text(r.1).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(r.0.sortDate.formatted(.dateTime.month(.abbreviated).day())).font(G.Fonts.ui(12)).foregroundStyle(G.Colors.textTertiary)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: G.Radius.md).fill(i == selected ? G.Colors.surfaceHover : .clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        if results.isEmpty {
                            Text(q.isEmpty ? "Type to search" : "No matches").foregroundStyle(G.Colors.textSecondary).padding(16)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 380)
            }
            .frame(width: 580)
            .background(RoundedRectangle(cornerRadius: 16).fill(G.Colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(G.Colors.border))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            .padding(.top, 90)
        }
        .onAppear { focused = true }
        .onChange(of: q) { _, _ in selected = 0 }
    }

    private var results: [(Note, String)] {
        let t = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return store.notes.prefix(8).map { ($0, $0.attendees.map(\.name).joined(separator: ", ")) } }
        return store.notes.compactMap { n in
            if n.title.lowercased().contains(t) { return (n, n.attendees.map(\.name).joined(separator: ", ")) }
            if let line = n.myNotes.split(separator: "\n").first(where: { $0.lowercased().contains(t) }) { return (n, String(line)) }
            if let e = n.enhanced, let l = e.sections.flatMap(\.lines).first(where: { $0.text.lowercased().contains(t) }) { return (n, l.text) }
            if let s = n.transcript.first(where: { $0.text.lowercased().contains(t) }) { return (n, "\(s.speaker): \(s.text)") }
            return nil
        }
    }

    private func open(_ i: Int) {
        guard results.indices.contains(i) else { return }
        model.searchPresented = false
        model.go(.note(results[i].0.id))
    }
}
