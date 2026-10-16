import AppKit
import SwiftUI

/// The one main window: hidden title bar, traffic lights over the content,
/// SwiftUI inside (Granola's layout).
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    static let shared = MainWindow()
    private var window: NSWindow?

    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.minSize = NSSize(width: 720, height: 520)
        w.title = "GranolaIsDead"
        w.isReleasedWhenClosed = false
        w.delegate = self
        let host = NSHostingView(rootView: RootView()
            .environmentObject(AppModel.shared)
            .environmentObject(NoteStore.shared)
            .environmentObject(MeetingRecorder.shared)
            .environmentObject(CalendarStore.shared)
            .environmentObject(SettingsStore.shared)
            .environmentObject(SpeechModel.shared))
        w.contentView = host
        w.setFrameAutosaveName("GranolaIsDeadMain")
        if !w.setFrameUsingName("GranolaIsDeadMain") { w.center() }
        window = w
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            if model.sidebarVisible {
                SidebarView()
                    .frame(width: 200)
                    .transition(.move(edge: .leading))
                Rectangle().fill(G.Colors.border.opacity(0.6)).frame(width: 1)
            }
            ZStack(alignment: .top) {
                G.Colors.background.ignoresSafeArea()
                content
                TopBar()
            }
        }
        .background(G.Colors.background)
        .ignoresSafeArea()
        .font(G.Fonts.body)
        .foregroundStyle(G.Colors.textPrimary)
        .tint(G.Colors.accent)
        .overlay {
            if model.searchPresented { SearchOverlay().transition(.opacity) }
        }
        .animation(G.Motion.gentle, value: model.sidebarVisible)
        .animation(G.Motion.gentle, value: model.searchPresented)
    }

    @ViewBuilder private var content: some View {
        switch model.route {
        case .home: HomeView(folder: nil)
        case .folder(let id): HomeView(folder: id)
        case .chat: GlobalChatView()
        case .note(let id): NoteView(noteID: id).id(id)
        }
    }
}

/// Top strip: sidebar toggle + search beside the traffic lights (only while
/// the sidebar is hidden), back/home on note pages, New note on the right.
struct TopBar: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var recorder: MeetingRecorder

    var body: some View {
        HStack(spacing: 6) {
            if !model.sidebarVisible {
                Color.clear.frame(width: 72, height: 1)
                IconButton(symbol: "sidebar.left", help: "Show sidebar  ⌘S") { model.sidebarVisible = true }
                IconButton(symbol: "magnifyingglass", help: "Search  ⌘K") { model.searchPresented = true }
            } else {
                Color.clear.frame(width: 8, height: 1)
            }
            if model.route != .home {
                PillButton {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                        Image(systemName: "house").font(.system(size: 13))
                    }
                } action: { model.go(.home) }
                .help("Home")
            }
            Spacer()
            if case .note = model.route {} else {
                PillButton {
                    Label { Text("New note") } icon: { Image(systemName: "plus") }.labelStyle(.titleAndIcon)
                } action: { model.newNote() }
                .help("New note  ⌘N")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}
