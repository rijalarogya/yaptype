import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                MainShellView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var pipeline: DictationPipeline
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Yaptype") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        .keyboardShortcut("o")

        Button("Note Taker") {
            AppNavigation.shared.go(.noteTaker)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        Button("Transcribe a file…") {
            AppNavigation.shared.chooseFile()
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        Divider()

        Text(pipeline.statusMessage)

        if AppInstaller.isRunningFromInstaller {
            Text("Open Yaptype from Applications, not the disk image.")
        } else if case .error(let message) = pipeline.phase {
            Text(message)
        }

        Divider()

        Button("Settings…") {
            AppNavigation.shared.go(.general)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Yaptype") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
