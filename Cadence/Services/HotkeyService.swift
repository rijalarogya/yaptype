import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class HotkeyService: ObservableObject {
    static let shared = HotkeyService()

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onCancel: (() -> Void)?

    @Published private(set) var isPressed = false
    @Published private(set) var tapRunning = false
    @Published var lastError: String?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?
    private var preset: HotkeyPreset = .rightOption
    private let stateLock = NSLock()
    private var pressed = false

    func start(preset: HotkeyPreset) {
        stop()
        self.preset = preset
        lastError = nil

        let mask =
            (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: hotkeyEventCallback,
            userInfo: pointer
        ) else {
            lastError = "Cadence needs Accessibility (and sometimes Input Monitoring) to listen for the dictation hotkey."
            tapRunning = false
            return
        }

        self.tap = tap
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
        thread.name = "cadence.hotkey"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop = tapRunLoop {
            CFRunLoopStop(runLoop)
        }
        tap = nil
        runLoopSource = nil
        tapThread = nil
        tapRunLoop = nil
        tapRunning = false
        setPressed(false)
    }

    fileprivate func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if type == .keyDown, keyCode == kVK_Escape, currentlyPressed {
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
            return nil
        case .release:
            if currentlyPressed {
                setPressed(false)
                DispatchQueue.main.async { self.onRelease?() }
            }
            return nil
        }
    }

    private var currentlyPressed: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return pressed
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
            return modifierMatch(type: type, keyCode: keyCode, expected: kVK_RightOption, flag: .maskAlternate, flags: flags)
        case .leftOption:
            return modifierMatch(type: type, keyCode: keyCode, expected: kVK_LeftOption, flag: .maskAlternate, flags: flags)
        case .rightShift:
            return modifierMatch(type: type, keyCode: keyCode, expected: kVK_RightShift, flag: .maskShift, flags: flags)
        case .rightCommand:
            return modifierMatch(type: type, keyCode: keyCode, expected: kVK_RightCommand, flag: .maskCommand, flags: flags)
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
        return flags.contains(flag) ? .press : .release
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
