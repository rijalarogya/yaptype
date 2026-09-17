import AppKit
import Foundation

enum AppInstaller {
    static let applicationsURL = URL(fileURLWithPath: "/Applications/Yaptype.app")

    static var isRunningFromInstaller: Bool {
        let path = Bundle.main.bundlePath
        if path.hasPrefix("/Volumes/") { return true }
        if path.contains("/.build/Yaptype.app") { return true }

        let url = Bundle.main.bundleURL
        let values = try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey, .volumeIsRemovableKey])
        if values?.volumeIsReadOnly == true, values?.volumeIsRemovable == true {
            return true
        }
        return false
    }

    /// Copies this app to /Applications and relaunches. Returns true if this process should stop starting up.
    @MainActor
    static func relocateToApplicationsIfNeeded() -> Bool {
        guard isRunningFromInstaller else { return false }
        let source = Bundle.main.bundleURL
        let destination = applicationsURL

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Move Yaptype to Applications"
            alert.informativeText = "You opened Yaptype from the installer disk. Drag Yaptype into Applications, then launch it from there. Opening it from the DMG breaks Microphone and Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
        }
        return true
    }
}
