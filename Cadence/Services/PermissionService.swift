import AppKit
import ApplicationServices
import AVFoundation
import Foundation

@MainActor
final class PermissionService: ObservableObject {
    static let shared = PermissionService()

    @Published private(set) var microphoneGranted = false
    @Published private(set) var accessibilityGranted = false

    var allGranted: Bool {
        microphoneGranted && accessibilityGranted
    }

    func refresh() {
        microphoneGranted = microphoneStatus
        accessibilityGranted = AXIsProcessTrusted()
    }

    var microphoneStatus: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophone() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneGranted = granted
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        if !accessibilityGranted {
            openAccessibilitySettings()
        }
    }

    func openMicrophoneSettings() {
        openPrivacyPane("Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openPrivacyPane("Privacy_ListenEvent")
    }

    private func openPrivacyPane(_ anchor: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}
