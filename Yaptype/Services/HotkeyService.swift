import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class HotkeyService: ObservableObject, @unchecked Sendable {
    static let shared = HotkeyService()

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onCancel: (() -> Void)?

    private var escapeEnabled = false

    @Published private(set) var isPressed = false
    @Published private(set) var tapRunning = false
    @Published var lastError: String?

    var hasEventTap: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return tap != nil
    }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?
    private var preset: HotkeyPreset = .rightOption
    private let stateLock = NSLock()
    private var pressed = false
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start(preset: HotkeyPreset) {
        stop()
        self.preset = preset
        lastError = nil

        let mask =
            (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        // defaultTap is gated by Accessibility. listenOnly is gated by Input Monitoring.
        if !installTap(options: .defaultTap, mask: mask, pointer: pointer) {
            _ = installTap(options: .listenOnly, mask: mask, pointer: pointer)
        }

        // A live event tap already sees every key. Extra NSEvent monitors
        // would fire the same press/release again.
        if tap == nil {
            startEventMonitors()
        }
        if tap == nil, globalMonitor == nil {
            lastError = "Yaptype needs Accessibility to listen for the dictation hotkey. If it is already on, remove old Yaptype rows and add this app, then quit and reopen."
        }
    }

    private func installTap(options: CGEventTapOptions, mask: Int, pointer: UnsafeMutableRawPointer) -> Bool {
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
            eventsOfInterest: CGEventMask(mask),
            callback: hotkeyEventCallback,
            userInfo: pointer
        ) else {
            return false
        }

        stateLock.lock()
        self.tap = tap
        stateLock.unlock()

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        tapRunning = true

        let thread = Thread { [weak self] in
            self?.tapRunLoop = CFRunLoopGetCurrent()
            if let source {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
            DispatchQueue.main.async {
                self?.tapRunning = false
            }
        }
        thread.name = "yaptype.hotkey"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop = tapRunLoop {
            CFRunLoopStop(runLoop)
        }
        stateLock.lock()
        tap = nil
        stateLock.unlock()
        runLoopSource = nil
        tapThread = nil
        tapRunLoop = nil
        tapRunning = false
        stopEventMonitors()
        setPressed(false)
    }

    private func startEventMonitors() {
        stopEventMonitors()
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleNSEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleNSEvent(event)
            return event
        }
        if globalMonitor != nil || localMonitor != nil {
            tapRunning = true
        }
    }

    private func stopEventMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleNSEvent(_ event: NSEvent) {
        guard let cgEvent = event.cgEvent else { return }
        _ = handle(event: cgEvent, type: cgEvent.type)
    }

    fileprivate func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if type == .keyDown, keyCode == kVK_Escape, currentlyPressed || isEscapeEnabled {
            setPressed(false)
            DispatchQueue.main.async { self.onCancel?() }
            return nil
        }

        switch matches(keyCode: keyCode, flags: flags, type: type) {
        case .ignore:
            return Unmanaged.passUnretained(event)
        case .press:
            if !currentlyPressed {
                setPressed(true)
                DispatchQueue.main.async { self.onPress?() }
            }
            // Keep modifier state in sync with macOS so release events still arrive.
            return Unmanaged.passUnretained(event)
        case .release:
            if currentlyPressed {
                setPressed(false)
                DispatchQueue.main.async { self.onRelease?() }
            }
            return Unmanaged.passUnretained(event)
        }
    }

    func setEscapeEnabled(_ value: Bool) {
        stateLock.lock()
        escapeEnabled = value
        stateLock.unlock()
    }

    private var currentlyPressed: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return pressed
    }

    private var isEscapeEnabled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return escapeEnabled
    }

    private func setPressed(_ value: Bool) {
        stateLock.lock()
        pressed = value
        stateLock.unlock()
        DispatchQueue.main.async { self.isPressed = value }
    }

    private enum Match {
        case ignore, press, release
    }

    private func matches(keyCode: Int, flags: CGEventFlags, type: CGEventType) -> Match {
        switch preset {
        case .rightOption:
            return modifierMatch(type: type, keyCode: keyCode, expected: 61, flag: .maskAlternate, flags: flags)
        case .leftOption:
            return modifierMatch(type: type, keyCode: keyCode, expected: 58, flag: .maskAlternate, flags: flags)
        case .rightShift:
            return modifierMatch(type: type, keyCode: keyCode, expected: 60, flag: .maskShift, flags: flags)
        case .rightCommand:
            return modifierMatch(type: type, keyCode: keyCode, expected: 54, flag: .maskCommand, flags: flags)
        case .functionF5:
            guard keyCode == kVK_F5 else { return .ignore }
            if type == .keyDown { return .press }
            if type == .keyUp { return .release }
            return .ignore
        case .controlSpace:
            guard keyCode == kVK_Space else { return .ignore }
            let hasControl = flags.contains(.maskControl)
            if type == .keyDown, hasControl { return .press }
            if type == .keyUp { return .release }
            return .ignore
        }
    }

    private func modifierMatch(
        type: CGEventType,
        keyCode: Int,
        expected: Int,
        flag: CGEventFlags,
        flags: CGEventFlags
    ) -> Match {
        guard type == .flagsChanged, keyCode == expected else { return .ignore }
        let deviceBit: CGEventFlags = {
            switch expected {
            case 61: CGEventFlags(rawValue: 0x00000040) // right Option
            case 58: CGEventFlags(rawValue: 0x00000020) // left Option
            case 60: CGEventFlags(rawValue: 0x00000004) // right Shift
            case 54: CGEventFlags(rawValue: 0x00000010) // right Command
            default: flag
            }
        }()
        let down = flags.contains(deviceBit) || flags.contains(flag)
        return down ? .press : .release
    }
}

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let service = Unmanaged<HotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.handle(event: event, type: type)
}
