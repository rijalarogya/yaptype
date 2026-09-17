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
            Text("Cadence")
                .font(.headline)
            Text(pipeline.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .error(let message) = pipeline.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            Button("Open Cadence") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("o")

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit Cadence") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(6)
        .frame(minWidth: 240)
    }
}
