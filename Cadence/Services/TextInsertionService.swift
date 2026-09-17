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
        case .pasteFailed: "Cadence could not paste into the focused app. Check Accessibility permission."
        }
    }
}

struct TextInsertionService: Sendable {
    func insert(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TextInsertionError.emptyText }

        if insertWithAccessibility(trimmed) {
            return
        }
        try insertWithClipboard(trimmed)
    }

    private func insertWithAccessibility(_ text: String) -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusedStatus == .success, let focused = focusedRef else { return false }

        let element = focused as! AXUIElement
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
                restorePasteboard(pasteboard, items: snapshot)
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
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
