import Carbon
import SwiftUI

/// Granola's Quick Chat: a global hotkey opens a floating "Ask anything" bar
/// that answers from your meetings without opening the main window.
/// ⌥Space when free; ⌃⌥Space when another app (a launcher) already owns it.
@MainActor
final class QuickChat: ObservableObject {
    static let shared = QuickChat()
    @Published var answer: String?
    @Published var asking = false
    private(set) var lastQuestion = ""
    @Published private(set) var hotkeyLabel: String?
    private var panel: FloatingPanel?
    private static let width: CGFloat = 620

    private var hotkeyID: UInt32?

    func registerHotkey() {
        if let hotkeyID { HotkeyCenter.shared.unregister(hotkeyID); self.hotkeyID = nil }
        hotkeyLabel = nil
        guard SettingsStore.shared.quickChatHotkey else { return }
        let space = UInt32(kVK_Space)
        if case .success(let id) = HotkeyCenter.shared.register(.init(keyCode: space, modifiers: UInt32(optionKey)), handler: { [weak self] in self?.toggle() }) {
            hotkeyID = id; hotkeyLabel = "⌥Space"
        } else if case .success(let id) = HotkeyCenter.shared.register(.init(keyCode: space, modifiers: UInt32(optionKey | controlKey)), handler: { [weak self] in self?.toggle() }) {
            hotkeyID = id; hotkeyLabel = "⌃⌥Space"
        }
    }

    func toggle() { panel == nil ? show() : hide() }

    /// Identifies the request whose answer may land; older ones are dropped.
    private var request = 0

    func show() {
        if let panel { panel.makeKeyAndOrderFront(nil); return } // already open: just focus it
        answer = nil; asking = false; request += 1
        let p = FloatingPanel(content: QuickChatView().environmentObject(self), fixedSize: true)
        p.dismissesOnResign = true
        p.onDismiss = { [weak self, weak p] in if let self, self.panel === p { self.panel = nil } }
        panel = p
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let v = screen?.visibleFrame else { return }
        p.setFrame(NSRect(x: v.midX - Self.width / 2, y: v.minY + v.height * 0.62, width: Self.width, height: 76), display: true)
        // Non-activating: the panel takes keys without pulling the main
        // window over what you were doing, and focus returns there on close.
        p.makeKeyAndOrderFront(nil)
        Analytics.track("app_quick_chat_opened")
    }

    func hide() { request += 1; asking = false; panel?.dismiss(); panel = nil }

    /// Grow downward from a fixed top edge as the answer arrives.
    private func resize(answerShown: Bool) {
        guard let p = panel else { return }
        let h: CGFloat = answerShown ? 380 : 76
        let top = p.frame.maxY
        p.setFrame(NSRect(x: p.frame.minX, y: top - h, width: Self.width, height: h), display: true, animate: true)
    }

    func ask(_ q: String) {
        guard !asking else { return }
        asking = true; answer = nil; lastQuestion = q
        request += 1; let mine = request
        resize(answerShown: true)
        let notes = NoteStore.shared.notes
        let picked = GlobalChatView.relevant(q, in: notes)
        let digest = Note(title: "Your meetings", myNotes: picked.map(GlobalChatView.digest).joined(separator: "\n\n"))
        Task {
            let a = picked.isEmpty ? "You don’t have any notes yet. Record a meeting and ask again."
                : await NoteEngine.answer(q, note: digest, history: [])
            guard mine == request else { return } // closed or re-asked meanwhile
            answer = a; asking = false
            Analytics.track("app_chat_asked", ["scope": "quick"])
        }
    }
}

private struct QuickChatView: View {
    @EnvironmentObject var chat: QuickChat
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(G.Colors.accent)
                TextField("Ask anything about your meetings", text: $text)
                    .textFieldStyle(.plain).font(G.Fonts.ui(17)).focused($focused)
                    .onSubmit { let q = text.trimmingCharacters(in: .whitespaces); if !q.isEmpty { chat.ask(q) } }
                if chat.asking { ProgressView().controlSize(.small) }
                Text("esc").font(G.Fonts.ui(11, .medium)).foregroundStyle(G.Colors.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(G.Colors.border))
            }
            .padding(.horizontal, 22).frame(height: 76)
            if chat.asking || chat.answer != nil {
                Divider().overlay(G.Colors.border)
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let a = chat.answer {
                            Text(displayMarkdown(a)).font(G.Fonts.ui(15)).lineSpacing(4).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 14) {
                                Button { copyToPasteboard(a) } label: { Label("Copy", systemImage: "doc.on.doc") }
                                Button { chat.hide(); MainWindow.shared.show(); AppModel.shared.pendingQuestion = chat.lastQuestion; AppModel.shared.go(.chat) } label: {
                                    Label("Continue in Chat", systemImage: "bubble.left")
                                }
                            }
                            .buttonStyle(.plain).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary)
                        } else {
                            Text("Reading your notes…").font(G.Fonts.ui(14)).foregroundStyle(G.Colors.textSecondary)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 22).fill(G.Colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(G.Colors.border))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .foregroundStyle(G.Colors.textPrimary)
        .tint(G.Colors.accent)
        .onAppear { DispatchQueue.main.async { focused = true } }
    }
}
