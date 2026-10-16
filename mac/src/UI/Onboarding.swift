import AVFoundation
import SwiftUI

/// First launch: what this is, then the three grants, then the speech model.
@MainActor
final class Onboarding {
    static let shared = Onboarding()
    private var window: NSWindow?

    func show(permissionsOnly: Bool = false) {
        let w = window ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
                                   styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true; w.titleVisibility = .hidden; w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: OnboardingView(step: permissionsOnly ? 1 : 0) { [weak self] in
            SettingsStore.shared.hasOnboarded = true
            self?.window?.close()
            MainWindow.shared.show()
        }
        .environmentObject(SpeechModel.shared).environmentObject(CalendarStore.shared))
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

struct OnboardingView: View {
    @State var step: Int
    let done: () -> Void
    @EnvironmentObject var speech: SpeechModel
    @State private var mic = Permissions.microphone == .authorized
    @State private var system = false
    @State private var calendar = Permissions.calendarGranted
    @State private var notify = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if step == 0 {
                Spacer()
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                Text("Meeting notes,\nwithout the bot.").font(G.Fonts.serif(36)).padding(.top, 20)
                Text("GranolaIsDead listens to your Mac's audio and microphone, transcribes on-device, and turns your rough notes into clean ones. Free, open source, no account.")
                    .font(G.Fonts.ui(15)).foregroundStyle(G.Colors.textSecondary).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
                Spacer()
                primary("Get started") { step = 1; speech.prepare() }
            } else {
                Text("A few permissions").font(G.Fonts.serif(30)).padding(.top, 44)
                Text("Everything stays on this Mac.").font(G.Fonts.ui(14)).foregroundStyle(G.Colors.textSecondary).padding(.top, 6).padding(.bottom, 22)
                perm("Microphone", "Transcribes what you say.", "mic", granted: mic) {
                    if Permissions.microphone == .denied { Permissions.openPrivacy(.microphone) }
                    else { mic = await Permissions.requestMicrophone() }
                }
                perm("System audio", "Hears the other side of the call. This is how no bot needs to join.", "speaker.wave.2", granted: system) {
                    system = Permissions.probeSystemAudio()
                    if !system { Permissions.openPrivacy(.systemAudio) }
                }
                perm("Calendar", "Shows what's coming up and names your notes. Optional.", "calendar", granted: calendar) {
                    if Permissions.calendarDecided && !Permissions.calendarGranted { Permissions.openPrivacy(.calendar) }
                    else { calendar = await Permissions.requestCalendar() }
                    CalendarStore.shared.refresh()
                }
                perm("Notifications", "Lets meeting prompts reach you. Optional.", "bell", granted: notify) {
                    notify = await Permissions.requestNotifications()
                }
                HStack(spacing: 8) {
                    switch speech.state {
                    case .downloading(let p):
                        ProgressView(value: p).frame(width: 120)
                        Text("Downloading the speech model (\(Int(p * 100))%). You can keep going.")
                    case .ready: Image(systemName: "checkmark.circle.fill").foregroundStyle(G.Colors.accent); Text("Speech model ready")
                    case .failed: Text("Speech model download failed.")
                        Button("Retry") { speech.prepare() }.buttonStyle(.plain).foregroundStyle(G.Colors.accent)
                    case .idle: Text("The speech model downloads in the background (about 600 MB).")
                    }
                }
                .font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary).padding(.top, 18)
                Spacer()
                primary(mic ? "Done" : "Skip for now", action: done)
            }
        }
        .padding(.horizontal, 44).padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(G.Colors.background)
        .foregroundStyle(G.Colors.textPrimary)
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            mic = Permissions.microphone == .authorized
            calendar = Permissions.calendarGranted
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(G.Fonts.ui(15, .medium)).foregroundStyle(G.Colors.onButton)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Capsule().fill(G.Colors.button))
        }
        .buttonStyle(.plain)
    }

    private func perm(_ title: String, _ detail: String, _ symbol: String, granted: Bool, action: @escaping () async -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 16)).frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(G.Colors.surface))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(G.Fonts.ui(14.5, .medium))
                Text(detail).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted { Image(systemName: "checkmark.circle.fill").foregroundStyle(G.Colors.accent).font(.system(size: 18)) }
            else { PillButton { Text("Allow") } action: { Task { await action() } } }
        }
        .padding(.vertical, 9)
    }
}
