import AppKit
import SwiftUI

@main
struct YaptypeApp: App {
    @NSApplicationDelegateAdaptor(YaptypeAppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var pipeline = DictationPipeline.shared
    @StateObject private var permissions = PermissionService.shared
    @StateObject private var models = ModelManager.shared
    @StateObject private var history = HistoryStore.shared
    @StateObject private var rewrite = RewriteService.shared
    @StateObject private var transcription = TranscriptionService.shared
    @StateObject private var navigation = AppNavigation.shared
    @StateObject private var notes = NoteTakerService.shared
    @StateObject private var files = FileTranscriptionService.shared

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
                .environmentObject(navigation)
                .environmentObject(notes)
                .environmentObject(files)
        } label: {
            Image(systemName: menuIcon)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.menu)

        Window("Yaptype", id: "main") {
            RootView()
                .environmentObject(settings)
                .environmentObject(pipeline)
                .environmentObject(permissions)
                .environmentObject(models)
                .environmentObject(history)
                .environmentObject(rewrite)
                .environmentObject(transcription)
                .environmentObject(navigation)
                .environmentObject(notes)
                .environmentObject(files)
                .preferredColorScheme(.light)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 760)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(pipeline)
                .environmentObject(permissions)
                .environmentObject(models)
                .environmentObject(history)
                .environmentObject(rewrite)
                .environmentObject(transcription)
                .environmentObject(navigation)
                .environmentObject(notes)
                .environmentObject(files)
                .preferredColorScheme(.light)
                .frame(width: 760, height: 560)
        }
    }

    private var menuIcon: String {
        switch pipeline.phase {
        case .recording: "waveform.circle.fill"
        case .preparing, .transcribing, .rewriting, .inserting: "ellipsis.circle.fill"
        case .error: "exclamationmark.circle.fill"
        case .idle: "mic.circle.fill"
        }
    }
}

final class YaptypeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppInstaller.relocateToApplicationsIfNeeded() {
            return
        }

        PermissionService.shared.refresh()
        ModelManager.shared.refreshInstalled()
        RewriteService.shared.refreshAvailability()
        DictationPipeline.shared.start()
        Task { @MainActor in
            await PermissionService.shared.requestMicrophoneIfNeeded()
            PermissionService.shared.requestMissing()
        }

        if AppSettings.shared.hasCompletedOnboarding {
            NSApp.setActivationPolicy(.regular)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openMainWindow()
            }
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
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "Yaptype" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
