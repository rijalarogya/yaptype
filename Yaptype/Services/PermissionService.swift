import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import Foundation
import IOKit.hid

@MainActor
final class PermissionService: ObservableObject {
    static let shared = PermissionService()

    @Published private(set) var microphoneGranted = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var hint: String?

    var onChange: (() -> Void)?

    var allGranted: Bool {
        microphoneGranted && accessibilityGranted
    }

    var runningPath: String {
        Bundle.main.bundlePath
    }

    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var captureSucceeded = false

    init() {
        refresh()
        startWatching()
    }

    func refresh() {
        let previous = (microphoneGranted, accessibilityGranted, inputMonitoringGranted)
        microphoneGranted = readMicrophoneGranted()
        accessibilityGranted = readAccessibilityGranted()
        inputMonitoringGranted = readInputMonitoringGranted()
        hint = makeHint()
        if previous != (microphoneGranted, accessibilityGranted, inputMonitoringGranted) {
            onChange?()
        }
    }

    func noteMicrophoneWorking() {
        captureSucceeded = true
        microphoneGranted = true
        hint = makeHint()
    }

    func requestMissing() {
        refresh()
        if !accessibilityGranted {
            requestAccessibility(openSettings: false)
        }
        if !inputMonitoringGranted {
            requestInputMonitoring(openSettings: false)
        }
    }

    func requestMicrophone() async {
        if #available(macOS 14.0, *) {
            if await AVAudioApplication.requestRecordPermission() {
                captureSucceeded = true
            }
        } else {
            if await AVCaptureDevice.requestAccess(for: .audio) {
                captureSucceeded = true
            }
        }
        refresh()
    }

    func requestMicrophoneIfNeeded() async {
        await requestMicrophone()
    }

    func requestAccessibility(openSettings: Bool = true) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
        if !accessibilityGranted, openSettings {
            openAccessibilitySettings()
        }
    }

    func requestInputMonitoring(openSettings: Bool = true) {
        _ = CGRequestListenEventAccess()
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        refresh()
        if !inputMonitoringGranted, openSettings {
            openInputMonitoringSettings()
        }
    }

    func openMicrophoneSettings() {
        openPrivacyPane(anchors: ["Privacy_Microphone"])
    }

    func openAccessibilitySettings() {
        openPrivacyPane(anchors: ["Privacy_Accessibility"])
    }

    func openInputMonitoringSettings() {
        openPrivacyPane(anchors: ["Privacy_ListenEvent"])
    }

    func relaunch() {
        let url = AppInstaller.isRunningFromInstaller ? AppInstaller.applicationsURL : Bundle.main.bundleURL
        let path = url.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = [
            "-c",
            "sleep 0.8; /usr/bin/open \"\(path)\""
        ]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func startWatching() {
        guard observers.isEmpty else { return }

        let center = DistributedNotificationCenter.default()
        observers.append(
            center.addObserver(
                forName: NSNotification.Name("com.apple.accessibility.api"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.refresh()
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        )

        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func readMicrophoneGranted() -> Bool {
        if captureSucceeded { return true }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { return true }
        if #available(macOS 14.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return false
    }

    private func readAccessibilityGranted() -> Bool {
        if AXIsProcessTrusted() { return true }
        let promptOff = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        if AXIsProcessTrustedWithOptions(promptOff) { return true }

        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedApplicationAttribute as CFString,
            &value
        )
        return result == .success || result == .noValue
    }

    private func readInputMonitoringGranted() -> Bool {
        if CGPreflightListenEventAccess() { return true }
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted {
            return true
        }
        return HotkeyService.shared.hasEventTap
    }

    private func makeHint() -> String? {
        if AppInstaller.isRunningFromInstaller {
            return "Open Yaptype from Applications, not the installer disk."
        }
        if allGranted {
            if inputMonitoringGranted { return nil }
            return "Input Monitoring is optional if the hotkey already works. If Right Option does nothing in other apps, add \(runningPath) there too."
        }
        if !microphoneGranted {
            return "Turn on Microphone for Yaptype in System Settings."
        }
        return """
        System Settings can show Yaptype as On for an older copy. This app is \(runningPath). In Accessibility (and Input Monitoring), select Yaptype, click −, click +, add that app, then Quit & Reopen.
        """
    }

    private func openPrivacyPane(anchors: [String]) {
        let prefixes = [
            "x-apple.systempreferences:com.apple.preference.security?",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?"
        ]
        for anchor in anchors {
            for prefix in prefixes {
                if let url = URL(string: prefix + anchor), NSWorkspace.shared.open(url) {
                    return
                }
            }
        }
    }
}
