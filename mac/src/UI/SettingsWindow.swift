import SwiftUI

@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show(tab: SettingsView.Tab = .general) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.contentView = NSHostingView(rootView: SettingsView(tab: tab)
            .environmentObject(SettingsStore.shared).environmentObject(CalendarStore.shared).environmentObject(SpeechModel.shared))
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    enum Tab: String, CaseIterable { case general = "General", calendar = "Calendar", ai = "AI", transcription = "Transcription", about = "About" }
    @State var tab: Tab
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Color.clear.frame(height: 38)
                ForEach(Tab.allCases, id: \.self) { t in
                    Button { tab = t } label: {
                        HStack(spacing: 10) {
                            Image(systemName: symbol(t)).frame(width: 18).foregroundStyle(G.Colors.textSecondary)
                            Text(t.rawValue).font(G.Fonts.ui(14))
                            Spacer()
                        }
                        .padding(.horizontal, 10).frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: G.Radius.md).fill(tab == t ? G.Colors.surface : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(10).frame(width: 190).background(G.Colors.sidebar)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(tab.rawValue).font(G.Fonts.serif(26)).padding(.bottom, 4)
                    switch tab {
                    case .general: GeneralPane()
                    case .calendar: CalendarPane()
                    case .ai: AIPane()
                    case .transcription: TranscriptionPane()
                    case .about: AboutPane()
                    }
                }
                .padding(.horizontal, 32).padding(.top, 40).padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(G.Colors.background)
        }
        .font(G.Fonts.body)
        .foregroundStyle(G.Colors.textPrimary)
        .tint(G.Colors.accent)
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private func symbol(_ t: Tab) -> String {
        switch t { case .general: "gearshape"; case .calendar: "calendar"; case .ai: "sparkles"; case .transcription: "waveform"; case .about: "info.circle" }
    }
}

struct SettingRow<Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let trailing: () -> Trailing
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(G.Fonts.ui(14, .medium))
                if let detail { Text(detail).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 6)
    }
}

private struct GeneralPane: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow(title: "Detect meetings", detail: "Offer to take notes when Zoom, Meet, Teams, FaceTime, Slack or Webex starts using the mic.") { Toggle("", isOn: $s.detectMeetings).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Remind me before meetings", detail: "A small prompt a minute before calendar events with other people.") { Toggle("", isOn: $s.calendarReminders).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Generate notes when a meeting ends", detail: "Turns your notes and the transcript into enhanced notes automatically.") { Toggle("", isOn: $s.autoEnhance).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Show floating recording indicator", detail: "A small pill on the edge of the screen while transcribing.") { Toggle("", isOn: $s.showFloatingIndicator).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Show upcoming meetings in menu bar", detail: "\"Standup • in 5m\" next to the menu-bar icon.") { Toggle("", isOn: $s.meetingInMenuBar).toggleStyle(.switch).labelsHidden() }
            SettingRow(title: "Quick Chat", detail: QuickChat.shared.hotkeyLabel.map { "Press \($0) anywhere to ask about your meetings." } ?? "Shortcut unavailable (another app uses ⌥Space and ⌃⌥Space). Open it from the menu-bar icon.") {
                PillButton { Text("Try it") } action: { QuickChat.shared.show() }
            }
            SettingRow(title: "Default template") {
                Picker("", selection: $s.defaultTemplate) { ForEach(NoteTemplate.all) { Text("\($0.symbol) \($0.name)").tag($0.id) } }.labelsHidden().frame(width: 220)
            }
            SettingRow(title: "Appearance") {
                Picker("", selection: $s.appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }
            SettingRow(title: "Permissions", detail: "Microphone, system audio and calendar.") {
                PillButton { Text("Review") } action: { Onboarding.shared.show(permissionsOnly: true) }
            }
        }
    }
}

private struct CalendarPane: View {
    @EnvironmentObject var cal: CalendarStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GranolaIsDead reads the calendars already set up in macOS Calendar (Google, Outlook, Exchange, iCloud). Nothing is sent anywhere.")
                .font(G.Fonts.ui(13.5)).foregroundStyle(G.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
            SettingRow(title: cal.authorized ? "Calendar connected" : "Calendar not connected",
                       detail: cal.authorized ? "\(cal.upcoming.count) events in the next week." : "Allow access to see what's coming up.") {
                if cal.authorized { PillButton { Text("Open Calendar settings") } action: { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!) } }
                else {
                    PillButton { Text("Connect") } action: {
                        Task { if Permissions.calendarDecided { Permissions.openPrivacy(.calendar) } else { _ = await Permissions.requestCalendar() }; cal.refresh() }
                    }
                }
            }
            Text("Missing a Google or Outlook calendar? Add the account in System Settings → Internet Accounts, then turn on Calendars.")
                .font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textTertiary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AIPane: View {
    @EnvironmentObject var s: SettingsStore
    @State private var key = ""
    @State private var status: String?
    @State private var testing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingRow(title: "On-device notes",
                       detail: NoteEngine.onDeviceAvailable ? "Apple's on-device model is ready. Notes are written on this Mac and never leave it."
                                                           : "Needs macOS 26 with Apple Intelligence turned on. Until then notes are basic (quoted from the transcript), or add your own key below.") {
                Image(systemName: NoteEngine.onDeviceAvailable ? "checkmark.circle.fill" : "minus.circle")
                    .foregroundStyle(NoteEngine.onDeviceAvailable ? G.Colors.accent : G.Colors.textTertiary)
            }
            Divider().padding(.vertical, 6)
            SettingRow(title: "Use my own API key", detail: "Optional. Sends the transcript and your notes to the provider you pick, with your key, for better notes and chat. The key stays in this Mac's Keychain.") {
                Toggle("", isOn: $s.writingModel.enabled).toggleStyle(.switch).labelsHidden()
            }
            if s.writingModel.enabled {
                SettingRow(title: "Provider") {
                    Picker("", selection: $s.writingModel.vendor) { ForEach(WritingVendor.allCases, id: \.self) { Text($0.label).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 200)
                        .onChange(of: s.writingModel.vendor) { _, v in s.writingModel.model = v.defaultModel; loadKey() }
                }
                SettingRow(title: "Model") { TextField("", text: $s.writingModel.model).textFieldStyle(.roundedBorder).frame(width: 220) }
                SettingRow(title: "\(s.writingModel.vendor.providerName) API key") {
                    SecureField(hasKey ? "Saved — paste to replace" : "Paste key", text: $key).textFieldStyle(.roundedBorder).frame(width: 220)
                        .onSubmit(saveKey)
                }
                if s.writingModel.vendor == .claude {
                    SettingRow(title: "Workspace ID", detail: "Only for user-level keys (sk-ant-usr-…).") {
                        TextField("wrkspc_…", text: $s.writingModel.claudeWorkspaceID).textFieldStyle(.roundedBorder).frame(width: 220)
                    }
                }
                HStack(spacing: 10) {
                    PillButton { Text("Save key") } action: { saveKey() }
                    PillButton { Text(testing ? "Testing…" : "Test") } action: { test() }
                    if hasKey { PillButton { Text("Remove key") } action: { Keychain.delete(service: s.writingModel.vendor.keychainService, account: WritingVendor.keychainAccount); status = "Key removed." } }
                }
                if let status { Text(status).font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textSecondary) }
            }
        }
    }

    private var hasKey: Bool { Keychain.read(service: s.writingModel.vendor.keychainService, account: WritingVendor.keychainAccount)?.isEmpty == false }
    private func loadKey() { key = "" }

    private func saveKey() {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { status = "Paste a key first."; return }
        do { try Keychain.save(k, service: s.writingModel.vendor.keychainService, account: WritingVendor.keychainAccount); key = ""; status = "Saved to Keychain." }
        catch { status = "Couldn’t save to Keychain." }
    }

    private func test() {
        if !key.isEmpty { saveKey() }
        guard let p = WritingModels.current(for: .brainChat) else { status = "Turn this on and save a key first."; return }
        testing = true
        Task {
            do {
                _ = try await p.generate(WritingRequest(instructions: "You are a connectivity check.", input: HostedHTTP.probePrompt, jsonSchema: nil, deadline: 30, purpose: .brainChat))
                status = "Works."
            } catch let e as WritingModelError { status = e.userMessage } catch { status = "Failed." }
            testing = false
        }
    }
}

private struct TranscriptionPane: View {
    @EnvironmentObject var speech: SpeechModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingRow(title: "Speech model", detail: "Parakeet, running on this Mac's Neural Engine. About 600 MB, downloaded once. Audio never leaves the Mac.") {
                switch speech.state {
                case .ready: Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(G.Colors.accent)
                case .downloading(let p): Text("\(Int(p * 100))%").monospacedDigit().foregroundStyle(G.Colors.textSecondary)
                case .failed: PillButton { Text("Retry download") } action: { speech.prepare() }
                case .idle: PillButton { Text("Download") } action: { speech.prepare() }
                }
            }
            SettingRow(title: "Recordings", detail: "Audio files are kept 14 days, then deleted. Transcripts and notes stay until you delete them.") {
                PillButton { Text("Show in Finder") } action: { NSWorkspace.shared.activateFileViewerSelecting([Paths.support]) }
            }
        }
    }
}

private struct AboutPane: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GranolaIsDead \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                .font(G.Fonts.ui(15, .medium))
            Text("A free, open-source Granola alternative. No account, no bot, no subscription. Not affiliated with Granola.")
                .font(G.Fonts.ui(13.5)).foregroundStyle(G.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                PillButton { Text("Check for updates") } action: { (NSApp.delegate as? AppDelegate)?.checkForUpdates() }
                PillButton { Text("Source on GitHub") } action: { (NSApp.delegate as? AppDelegate)?.openGitHub() }
                PillButton { Text("Report an issue") } action: { (NSApp.delegate as? AppDelegate)?.reportIssue() }
            }
            Divider().padding(.vertical, 6)
            SettingRow(title: "Share anonymous usage stats", detail: "Counts like \"a meeting was recorded\". Never notes, transcripts, titles or names.") {
                Toggle("", isOn: Binding(get: { !s.analyticsOptOut }, set: { s.analyticsOptOut = !$0 })).toggleStyle(.switch).labelsHidden()
            }
        }
    }
}
