import Foundation
import ServiceManagement
import SwiftUI

enum HotkeyPreset: String, CaseIterable, Identifiable, Codable {
    case rightOption
    case leftOption
    case rightShift
    case rightCommand
    case functionF5
    case controlSpace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rightOption: "Right Option (⌥)"
        case .leftOption: "Left Option (⌥)"
        case .rightShift: "Right Shift"
        case .rightCommand: "Right Command (⌘)"
        case .functionF5: "F5"
        case .controlSpace: "Control + Space"
        }
    }

    var hint: String {
        switch self {
        case .rightOption: "Hold Right Option to dictate"
        case .leftOption: "Hold Left Option to dictate"
        case .rightShift: "Hold Right Shift to dictate"
        case .rightCommand: "Hold Right Command to dictate"
        case .functionF5: "Hold F5 to dictate"
        case .controlSpace: "Hold Control + Space to dictate"
        }
    }
}

enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case auto
    case en
    case es
    case fr
    case de
    case zh
    case ja
    case ko
    case hi
    case ar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .en: "English"
        case .es: "Spanish"
        case .fr: "French"
        case .de: "German"
        case .zh: "Chinese"
        case .ja: "Japanese"
        case .ko: "Korean"
        case .hi: "Hindi"
        case .ar: "Arabic"
        }
    }

    var needsMultilingualModel: Bool {
        self != .en
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("selectedModelID") var selectedModelID = WhisperModelSpec.recommended.id
    @AppStorage("dictationLanguage") var languageRaw = TranscriptionLanguage.auto.rawValue
    @AppStorage("rewriteEnabled") var rewriteEnabled = true
    @AppStorage("preferAppleIntelligence") var preferAppleIntelligence = true
    @AppStorage("hotkey") var hotkeyRaw = HotkeyPreset.rightOption.rawValue
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("mlxModelID") var mlxModelID = MLXModelSpec.recommended.id

    var hotkey: HotkeyPreset {
        get { HotkeyPreset(rawValue: hotkeyRaw) ?? .rightOption }
        set { hotkeyRaw = newValue.rawValue }
    }

    var language: TranscriptionLanguage {
        get { TranscriptionLanguage(rawValue: languageRaw) ?? .auto }
        set { languageRaw = newValue.rawValue }
    }

    func binding<Value>(_ keyPath: ReferenceWritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { newValue in
                self.objectWillChange.send()
                self[keyPath: keyPath] = newValue
            }
        )
    }

    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Yaptype: launch-at-login failed: \(error.localizedDescription)")
        }
    }
}
