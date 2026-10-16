import AppKit
import Combine
import Foundation

/// App preferences (UserDefaults). Tiny on purpose.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let d = UserDefaults.standard

    @Published var detectMeetings: Bool { didSet { d.set(detectMeetings, forKey: "detectMeetings") } }
    @Published var calendarReminders: Bool { didSet { d.set(calendarReminders, forKey: "calendarReminders") } }
    @Published var autoEnhance: Bool { didSet { d.set(autoEnhance, forKey: "autoEnhance") } }
    @Published var showFloatingIndicator: Bool { didSet { d.set(showFloatingIndicator, forKey: "showFloatingIndicator") } }
    @Published var defaultTemplate: String { didSet { d.set(defaultTemplate, forKey: "defaultTemplate") } }
    @Published var appearance: String { didSet { d.set(appearance, forKey: "appearance"); applyAppearance() } }
    @Published var analyticsOptOut: Bool { didSet { d.set(analyticsOptOut, forKey: "analyticsOptOut") } }
    @Published var hasOnboarded: Bool { didSet { d.set(hasOnboarded, forKey: "hasOnboarded") } }
    @Published var writingModel: WritingModelSettings { didSet { saveWritingModel() } }

    private init() {
        d.register(defaults: ["detectMeetings": true, "calendarReminders": true, "autoEnhance": true,
                              "showFloatingIndicator": true, "defaultTemplate": NoteTemplate.auto.id, "appearance": "system"])
        detectMeetings = d.bool(forKey: "detectMeetings")
        calendarReminders = d.bool(forKey: "calendarReminders")
        autoEnhance = d.bool(forKey: "autoEnhance")
        showFloatingIndicator = d.bool(forKey: "showFloatingIndicator")
        defaultTemplate = d.string(forKey: "defaultTemplate") ?? NoteTemplate.auto.id
        appearance = d.string(forKey: "appearance") ?? "system"
        analyticsOptOut = d.bool(forKey: "analyticsOptOut")
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        var w = WritingModelSettings()
        w.enabled = d.bool(forKey: "ai.enabled")
        w.vendor = WritingVendor(rawValue: d.string(forKey: "ai.vendor") ?? "") ?? .claude
        w.model = d.string(forKey: "ai.model") ?? w.vendor.defaultModel
        w.claudeWorkspaceID = d.string(forKey: "ai.claudeWorkspace") ?? ""
        writingModel = w
    }

    private func saveWritingModel() {
        d.set(writingModel.enabled, forKey: "ai.enabled")
        d.set(writingModel.vendor.rawValue, forKey: "ai.vendor")
        d.set(writingModel.model, forKey: "ai.model")
        d.set(writingModel.claudeWorkspaceID, forKey: "ai.claudeWorkspace")
    }

    func applyAppearance() {
        switch appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}
