import AppKit
import AVFoundation
import EventKit
import UserNotifications

/// The three grants the app needs: microphone (you), system audio (them —
/// "System Audio Recording Only", no Screen Recording needed) and calendar
/// (optional, for "Coming up" and reminders).
@MainActor
enum Permissions {
    enum Kind { case microphone, systemAudio, calendar, notifications }

    static var microphone: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }

    static func requestMicrophone() async -> Bool {
        switch microphone {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    /// There is no status API for the audio-capture grant; creating a tap is
    /// the probe (and triggers the prompt the first time).
    static func probeSystemAudio() -> Bool { SystemAudioTap.hasPermission() }

    static var calendarGranted: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    static var calendarDecided: Bool { EKEventStore.authorizationStatus(for: .event) != .notDetermined }

    static func requestCalendar() async -> Bool {
        let store = EKEventStore()
        let ok = (try? await store.requestFullAccessToEvents()) ?? false
        NotificationCenter.default.post(name: .gidPermissionsChanged, object: nil)
        return ok
    }

    static func requestNotifications() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func openPrivacy(_ kind: Kind) {
        let anchor: String
        switch kind {
        case .microphone: anchor = "Privacy_Microphone"
        case .systemAudio: anchor = "Privacy_ScreenCapture"
        case .calendar: anchor = "Privacy_Calendars"
        case .notifications: anchor = "Notifications"
        }
        let url = kind == .notifications
            ? URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
            : URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        NSWorkspace.shared.open(url)
    }
}

extension Notification.Name {
    static let gidPermissionsChanged = Notification.Name("gid.permissionsChanged")
}
