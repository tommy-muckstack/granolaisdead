import AppKit
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    private var updater: SPUStandardUpdaterController?
    private var statusItem: NSStatusItem?
    private let detector = MeetingDetector()

    func applicationDidFinishLaunching(_ notification: Notification) {
        G.Fonts.register()
        SettingsStore.shared.applyAppearance()
        SystemAudioTap.cleanupStaleDevices()
        Recordings.cleanupOld()
        if Bundle.main.bundleURL.pathExtension == "app" {
            updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        }
        installMenus()
        installStatusItem()
        MainWindow.shared.show()
        if !SettingsStore.shared.hasOnboarded { Onboarding.shared.show() }
        else { SpeechModel.shared.prepare() }

        CalendarStore.shared.onStartingSoon = { ev in
            guard SettingsStore.shared.calendarReminders, !MeetingRecorder.shared.isBusy else { return }
            MeetingPrompt.shared.show(title: ev.title, subtitle: "Starting in 1 minute", event: ev)
        }
        CalendarStore.shared.start()
        detector.isOwnAudioActive = { MeetingRecorder.shared.isBusy }
        detector.onMeetingDetected = { app in
            guard SettingsStore.shared.detectMeetings, !MeetingRecorder.shared.isBusy else { return }
            let ev = CalendarStore.shared.upcoming.first { $0.isNow || abs($0.start.timeIntervalSinceNow) < 600 }
            MeetingPrompt.shared.show(title: ev?.title ?? "Meeting detected", subtitle: "\(app) is using your microphone", event: ev)
            Analytics.track("app_meeting_detected", ["app": app])
        }
        detector.start()
        Analytics.track("app_opened")
        applyDebugRoute()
    }

    /// Dev hook for screenshot checks: GID_ROUTE=note:<uuid>[:transcript|:chat|:mynotes] | chat | settings:<Tab> | search
    private func applyDebugRoute() {
        guard let r = ProcessInfo.processInfo.environment["GID_ROUTE"] else { return }
        let parts = r.split(separator: ":").map(String.init)
        NSLog("GranolaIsDead [debug] route %@", r)
        switch parts.first {
        case "note":
            guard parts.count > 1, let id = UUID(uuidString: parts[1]) else { return }
            AppModel.shared.go(.note(id))
            if parts.count > 2 {
                if parts[2] == "mynotes" { AppModel.shared.showEnhanced[id] = false }
                else { AppModel.shared.debugPanel = parts[2] }
            }
        case "chat": AppModel.shared.go(.chat)
        case "search": AppModel.shared.searchPresented = true
        case "settings": SettingsWindow.shared.show(tab: SettingsView.Tab(rawValue: parts.count > 1 ? parts[1] : "General") ?? .general)
        default: break
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindow.shared.show(); return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let rec = MeetingRecorder.shared
        if rec.isBusy {
            let a = NSAlert()
            a.messageText = "Stop recording and quit?"
            a.informativeText = "The transcript so far is saved."
            a.addButton(withTitle: "Stop and Quit"); a.addButton(withTitle: "Cancel")
            guard a.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
            rec.stop()
        }
        guard !rec.finishing.isEmpty else { NoteStore.shared.flushAll(sync: true); return .terminateNow }
        // Let the last chunks finish transcribing (up to a minute), then write.
        Task { @MainActor in
            var waited = 0
            while !rec.finishing.isEmpty, waited < 240 { try? await Task.sleep(for: .milliseconds(250)); waited += 1 }
            NoteStore.shared.flushAll(sync: true)
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    // Never restart for an update in the middle of a meeting.
    nonisolated func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool { true }
    nonisolated func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        let busy = MainActor.assumeIsolated { MeetingRecorder.shared.isBusy || !MeetingRecorder.shared.finishing.isEmpty || !AppModel.shared.enhancing.isEmpty }
        guard busy else { return false }
        Task { @MainActor in
            while MeetingRecorder.shared.isBusy || !MeetingRecorder.shared.finishing.isEmpty || !AppModel.shared.enhancing.isEmpty {
                try? await Task.sleep(for: .seconds(5))
            }
            installHandler()
        }
        return true
    }

    @objc func checkForUpdates() {
        if let updater { updater.checkForUpdates(nil) }
        else { Toast.show("Updates work in the installed app, not a dev build.", systemImage: "arrow.down.circle") }
    }

    @objc func openSettings() { SettingsWindow.shared.show() }
    @objc func newNote() { AppModel.shared.newNote() }
    @objc func newRecording() { AppModel.shared.newNote(record: true) }
    @objc func toggleRecording() {
        if MeetingRecorder.shared.isRecording { AppModel.shared.stopRecording() }
        else if case .note(let id) = AppModel.shared.route { AppModel.shared.startRecording(id) }
        else { AppModel.shared.newNote(record: true) }
    }
    @objc func toggleSidebar() { withAnimation(G.Motion.gentle) { AppModel.shared.sidebarVisible.toggle() } }
    @objc func search() { MainWindow.shared.show(); AppModel.shared.searchPresented = true }
    @objc func showMain() { MainWindow.shared.show() }
    @objc func goHome() { AppModel.shared.go(.home) }
    @objc func openGitHub() { NSWorkspace.shared.open(URL(string: "https://github.com/tommy-muckstack/granolaisdead")!) }
    @objc func reportIssue() { NSWorkspace.shared.open(URL(string: "https://github.com/tommy-muckstack/granolaisdead/issues/new")!) }

    // MARK: Menus

    private func installMenus() {
        let main = NSMenu()
        func item(_ title: String, _ sel: Selector?, _ key: String = "", _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: key); i.keyEquivalentModifierMask = mods; i.target = sel.map { _ in self }; return i
        }
        let app = NSMenu(title: "GranolaIsDead")
        app.addItem(NSMenuItem(title: "About GranolaIsDead", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        app.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        app.addItem(.separator())
        app.addItem(item("Settings…", #selector(openSettings), ","))
        app.addItem(.separator())
        app.addItem(NSMenuItem(title: "Hide GranolaIsDead", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let others = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"); others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(others)
        app.addItem(.separator())
        app.addItem(NSMenuItem(title: "Quit GranolaIsDead", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        add(app, to: main)

        let file = NSMenu(title: "File")
        file.addItem(item("New Note", #selector(newNote), "n"))
        file.addItem(item("New Note and Record", #selector(newRecording), "n", [.command, .shift]))
        file.addItem(item("Start or Stop Recording", #selector(toggleRecording), "r", [.command, .shift]))
        file.addItem(.separator())
        file.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        add(file, to: main)

        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z"); redo.keyEquivalentModifierMask = [.command, .shift]; edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        edit.addItem(.separator())
        edit.addItem(item("Search Notes…", #selector(search), "k"))
        add(edit, to: main)

        let view = NSMenu(title: "View")
        view.addItem(item("Home", #selector(goHome), "1"))
        view.addItem(item("Toggle Sidebar", #selector(toggleSidebar), "s"))
        add(view, to: main)

        let window = NSMenu(title: "Window")
        window.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        window.addItem(item("GranolaIsDead", #selector(showMain), "0"))
        add(window, to: main); NSApp.windowsMenu = window

        let help = NSMenu(title: "Help")
        help.addItem(item("Source Code on GitHub", #selector(openGitHub)))
        help.addItem(item("Report an Issue", #selector(reportIssue)))
        add(help, to: main)
        NSApp.mainMenu = main
    }

    private func add(_ menu: NSMenu, to main: NSMenu) {
        let i = NSMenuItem(title: menu.title, action: nil, keyEquivalent: ""); i.submenu = menu; main.addItem(i)
    }

    private func installStatusItem() {
        let s = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        s.button?.image = Mark.menuBarImage(); s.button?.toolTip = "GranolaIsDead"
        let m = NSMenu()
        let open = NSMenuItem(title: "Open GranolaIsDead", action: #selector(showMain), keyEquivalent: ""); open.target = self; m.addItem(open)
        let rec = NSMenuItem(title: "New Note and Record", action: #selector(newRecording), keyEquivalent: ""); rec.target = self; m.addItem(rec)
        let stop = NSMenuItem(title: "Start or Stop Recording", action: #selector(toggleRecording), keyEquivalent: ""); stop.target = self; m.addItem(stop)
        m.addItem(.separator())
        let set = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ""); set.target = self; m.addItem(set)
        let upd = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: ""); upd.target = self; m.addItem(upd)
        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        s.menu = m
        statusItem = s
    }
}

MainActor.assumeIsolated {
    if DebugCLI.runIfRequested() { RunLoop.main.run() }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
