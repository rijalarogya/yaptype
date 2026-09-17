import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                SettingsView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var pipeline: DictationPipeline
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var permissions: PermissionService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Yaptype")
                .font(.headline)
            Text(pipeline.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if AppInstaller.isRunningFromInstaller {
                Text("This window is the installer disk. Yaptype should open from Applications after it copies itself.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if case .error(let message) = pipeline.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            Button("Open Yaptype") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("o")

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit Yaptype") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(6)
        .frame(minWidth: 240)
    }
}
