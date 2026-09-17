import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum TextInsertionError: LocalizedError {
    case emptyText
    case pasteFailed

    var errorDescription: String? {
        switch self {
        case .emptyText: "Nothing to insert."
        case .pasteFailed: "Yaptype could not paste into the focused app. Check Accessibility permission."
        }
    }
}

@MainActor
final class TextInsertionService {
    private var targetApp: NSRunningApplication?
    private var targetElement: AXUIElement?
    private var observer: NSObjectProtocol?

    init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                self?.remember(app: app)
            }
        }
        rememberTarget()
    }

    func rememberTarget() {
        if let app = NSWorkspace.shared.frontmostApplication {
            remember(app: app)
        }
        if let element = copyFocusedElement(), !isYaptype(element) {
            targetElement = element
        }
    }

    private func remember(app: NSRunningApplication) {
        guard !isYaptype(app) else { return }
        targetApp = app
    }

    func insert(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TextInsertionError.emptyText }

        rememberTarget()
        await activateTarget()

        if let element = targetElement, setSelectedText(element, trimmed) {
            return
        }
        if let focused = copyFocusedElement(), !isYaptype(focused), setSelectedText(focused, trimmed) {
            return
        }
        try insertWithClipboard(trimmed)
    }

    private func activateTarget() async {
        guard let app = targetApp, !app.isTerminated else { return }
        if #available(macOS 14.0, *) {
            _ = app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        try? await Task.sleep(for: .milliseconds(90))
    }

    private func copyFocusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard status == .success, let focusedRef else { return nil }
        return (focusedRef as! AXUIElement)
    }

    private func setSelectedText(_ element: AXUIElement, _ text: String) -> Bool {
        var selectedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedRef)
        let before = selectedRef as? String

        let setStatus = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        guard setStatus == .success else { return false }

        var afterRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &afterRef)
        let after = afterRef as? String
        if after == text { return true }
        if before != after, after?.contains(text) == true { return true }
        return after != before
    }

    private func insertWithClipboard(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)
        let changeCount = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        guard pasteboard.setString(text, forType: .string) else {
            restorePasteboard(pasteboard, items: snapshot)
            throw TextInsertionError.pasteFailed
        }

        try postPaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if pasteboard.changeCount == changeCount + 1 || pasteboard.string(forType: .string) == text {
                self.restorePasteboard(pasteboard, items: snapshot)
            }
        }
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        pasteboard.pasteboardItems?.map { item in
            var encoded: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    encoded[type] = data
                }
            }
            return encoded
        } ?? []
    }

    private func restorePasteboard(
        _ pasteboard: NSPasteboard,
        items: [[NSPasteboard.PasteboardType: Data]]
    ) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { encoded -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in encoded {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restored)
    }

    private func postPaste() throws {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            throw TextInsertionError.pasteFailed
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func isYaptype(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == ProcessInfo.processInfo.processIdentifier
            || app.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private func isYaptype(_ element: AXUIElement) -> Bool {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid == ProcessInfo.processInfo.processIdentifier
    }
}
