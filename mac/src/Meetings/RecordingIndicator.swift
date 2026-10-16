import AppKit
import Combine
import SwiftUI

/// Floating pill on the right edge while transcribing: live bars + elapsed
/// time. Click opens the note; the stop button ends the meeting.
@MainActor
final class RecordingIndicator {
    static let shared = RecordingIndicator()
    private var panel: NSPanel?

    func show() {
        guard SettingsStore.shared.showFloatingIndicator, panel == nil, let screen = NSScreen.main else { return }
        let size = NSSize(width: 132, height: 40)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        p.level = .floating; p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        let host = NSHostingView(rootView: IndicatorView().environmentObject(MeetingRecorder.shared))
        host.frame = NSRect(origin: .zero, size: size)
        p.contentView = host
        let v = screen.visibleFrame
        // Granola's spot: right edge, 70% up. Dragged positions are remembered.
        p.setFrameOrigin(NSPoint(x: v.maxX - size.width - 16, y: v.minY + v.height * 0.7))
        p.setFrameAutosaveName("GranolaIsDeadIndicator")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(p.frame) }) {
            p.setFrameOrigin(NSPoint(x: v.maxX - size.width - 16, y: v.minY + v.height * 0.7))
        }
        p.orderFrontRegardless()
        panel = p
    }

    func hide() { panel?.saveFrame(usingName: "GranolaIsDeadIndicator"); panel?.orderOut(nil); panel = nil }
}

private struct IndicatorView: View {
    @EnvironmentObject var recorder: MeetingRecorder
    @State private var quietSince: Date?
    @State private var quiet = false
    private let poll = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if let id = recorder.noteID { AppModel.shared.go(.note(id)) }
            } label: {
                HStack(spacing: 8) {
                    // Bars turn red after 3 s of silence (is the mic muted?).
                    Waveform(level: max(recorder.micLevel, recorder.systemLevel), active: !recorder.isPaused,
                             color: quiet ? G.Colors.recording : G.Colors.audio)
                    Text(Note.stamp(recorder.elapsed)).font(G.Fonts.ui(12.5, .medium).monospacedDigit()).foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain).help("Open note")
            Button { AppModel.shared.stopRecording() } label: {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.85)).frame(width: 9, height: 9)
                    .frame(width: 22, height: 22).background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain).help("Stop transcribing")
        }
        .padding(.horizontal, 12)
        .frame(width: 132, height: 40)
        .background(Capsule().fill(Color(nsColor: NSColor(hex: 0x1F1F1E))))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
        .help(quiet ? "Nothing heard for a few seconds. Is your mic muted?" : "GranolaIsDead is transcribing")
        .onReceive(poll) { _ in
            let loud = max(recorder.micLevel, recorder.systemLevel) > 0.04
            if loud || recorder.isPaused { quietSince = nil; quiet = false }
            else if quietSince == nil { quietSince = Date() }
            else if let q = quietSince, Date().timeIntervalSince(q) > 3 { quiet = true }
        }
    }
}

/// "Meeting detected" / "Starting soon" prompt, top-right, Granola-style.
@MainActor
final class MeetingPrompt {
    static let shared = MeetingPrompt()
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(title: String, subtitle: String, event: CalendarStore.Event?) {
        hide()
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 340, height: 92)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        p.level = .statusBar; p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: PromptView(title: title, subtitle: subtitle, joinURL: event?.joinURL,
            start: { [weak self] in
                self?.hide()
                if let url = event?.joinURL, event.map({ !$0.isNow }) == true { NSWorkspace.shared.open(url) }
                AppModel.shared.newNote(record: true, event: event)
                Analytics.track("app_prompt_accepted")
            },
            dismiss: { [weak self] in self?.hide() }))
        host.frame = NSRect(origin: .zero, size: size)
        p.contentView = host
        let v = screen.visibleFrame
        p.setFrameOrigin(NSPoint(x: v.maxX - size.width - 18, y: v.maxY - size.height - 14))
        p.orderFrontRegardless()
        panel = p
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(45))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() { dismissTask?.cancel(); panel?.orderOut(nil); panel = nil }
}

private struct PromptView: View {
    let title: String, subtitle: String
    let joinURL: URL?
    let start: () -> Void, dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(G.Fonts.ui(14, .semibold)).lineLimit(1)
                Text(subtitle).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary).lineLimit(1)
                HStack(spacing: 8) {
                    Button(action: start) {
                        Text(joinURL != nil ? "Join & take notes" : "Take notes").font(G.Fonts.ui(12.5, .semibold)).foregroundStyle(G.Colors.onButton)
                            .padding(.horizontal, 12).frame(height: 26).background(Capsule().fill(G.Colors.button))
                    }.buttonStyle(.plain)
                    Button("Not now", action: dismiss).buttonStyle(.plain).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 340, height: 92)
        .background(RoundedRectangle(cornerRadius: 16).fill(G.Colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(G.Colors.border))
        .foregroundStyle(G.Colors.textPrimary)
    }
}

/// "Are you still there?" after a long silence, with Granola's 60 s countdown.
@MainActor
final class StillThereCard {
    static let shared = StillThereCard()
    private var panel: NSPanel?

    func show(_ done: @escaping (_ stop: Bool) -> Void) {
        hide()
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 360, height: 132)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        p.level = .statusBar; p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: StillThereView { [weak self] stop in self?.hide(); done(stop) })
        host.frame = NSRect(origin: .zero, size: size)
        p.contentView = host
        let v = screen.visibleFrame
        p.setFrameOrigin(NSPoint(x: v.maxX - size.width - 18, y: v.maxY - size.height - 14))
        p.orderFrontRegardless()
        panel = p
        NSSound(named: "Tink")?.play()
    }

    func hide() { panel?.orderOut(nil); panel = nil }
}

private struct StillThereView: View {
    let done: (Bool) -> Void
    @State private var left = 60
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Are you still there?").font(G.Fonts.ui(14, .semibold))
            Text("We haven't heard anything in a while, so transcription stops in \(left) seconds.")
                .font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { done(false) } label: {
                    Text("I'm still here").font(G.Fonts.ui(12.5, .semibold)).foregroundStyle(G.Colors.onButton)
                        .padding(.horizontal, 12).frame(height: 26).background(Capsule().fill(G.Colors.button))
                }.buttonStyle(.plain)
                Button("Stop transcribing") { done(true) }.buttonStyle(.plain).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 360, height: 132, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(G.Colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(G.Colors.border))
        .foregroundStyle(G.Colors.textPrimary)
        .onReceive(timer) { _ in left -= 1; if left <= 0 { done(true) } }
    }
}
