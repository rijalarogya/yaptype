import AppKit
import SwiftUI

@main
struct CadenceApp: App {
    @NSApplicationDelegateAdaptor(CadenceAppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var pipeline = DictationPipeline.shared
    @StateObject private var permissions = PermissionService.shared
    @StateObject private var models = ModelManager.shared
    @StateObject private var history = HistoryStore.shared
    @StateObject private var rewrite = RewriteService.shared
    @StateObject private var transcription = TranscriptionService.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(settings)
                .environmentObject(pipeline)
                .environmentObject(permissions)
                .environmentObject(models)
                .environmentObject(history)
                .environmentObject(rewrite)
                .environmentObject(transcription)
        } label: {
            Image(systemName: menuIcon)
                .symbolRenderingMode(.hierarchical)
        }

        Window("Cadence", id: "main") {
            RootView()
                .environmentObject(settings)
                .environmentObject(pipeline)
                .environmentObject(permissions)
                .environmentObject(models)
                .environmentObject(history)
                .environmentObject(rewrite)
                .environmentObject(transcription)
                .frame(minWidth: 640, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 560)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(pipeline)
                .environmentObject(permissions)
                .environmentObject(models)
                .environmentObject(history)
                .environmentObject(rewrite)
                .environmentObject(transcription)
                .frame(width: 640, height: 520)
        }
    }

    private var menuIcon: String {
        switch pipeline.phase {
        case .recording: "waveform.circle.fill"
        case .transcribing, .rewriting, .inserting: "ellipsis.circle.fill"
        case .error: "exclamationmark.circle.fill"
        case .idle: "mic.circle.fill"
        }
    }
}

final class CadenceAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionService.shared.refresh()
        ModelManager.shared.refreshInstalled()
        RewriteService.shared.refreshAvailability()
        DictationPipeline.shared.start()

        if AppSettings.shared.hasCompletedOnboarding {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.openMainWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "Cadence" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
