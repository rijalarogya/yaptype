import AppKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var permissions: PermissionService
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var pipeline: DictationPipeline
    @EnvironmentObject private var transcription: TranscriptionService

    @State private var downloading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    permissionCard(
                        title: "Microphone",
                        detail: "Yaptype records only while you hold the hotkey. Audio never leaves this Mac.",
                        granted: permissions.microphoneGranted,
                        actionTitle: permissions.microphoneGranted ? "Granted" : "Allow microphone"
                    ) {
                        Task { await permissions.requestMicrophone() }
                    }

                    permissionCard(
                        title: "Accessibility",
                        detail: "Needed to type into the app you are already in. If System Settings already shows Yaptype on, it is an older copy: select Yaptype, click −, click +, add /Applications/Yaptype.app, then Quit & Reopen.",
                        granted: permissions.accessibilityGranted,
                        actionTitle: permissions.accessibilityGranted ? "Granted" : "Allow Accessibility"
                    ) {
                        permissions.requestAccessibility()
                    }

                    modelCard
                }
                .padding(24)
            }
            Divider()
            HStack {
                Text("Hold \(settings.hotkey.title) after setup. Esc cancels a take.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Continue") {
                    settings.hasCompletedOnboarding = true
                    NSApp.setActivationPolicy(.regular)
                    pipeline.restartHotkey()
                    pipeline.refreshStatus()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!permissions.allGranted || !models.installedIDs.contains(settings.selectedModelID))
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            permissions.refresh()
            models.refreshInstalled()
        }
        .onReceive(Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()) { _ in
            permissions.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            YaptypeLogoMark(size: 52)
            VStack(alignment: .leading, spacing: 8) {
                Text("Yaptype")
                    .font(.system(size: 28, weight: .semibold))
                Text("Hold a key and speak any language. Text is typed as you said it. Whisper stays on this Mac.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
    }

    private var modelCard: some View {
        let spec = WhisperModelSpec.spec(for: settings.selectedModelID) ?? .recommended
        let installed = models.isInstalled(spec)

        return VStack(alignment: .leading, spacing: 10) {
            Label("Download \(spec.title)", systemImage: "arrow.down.circle")
                .font(.headline)
            Text("Needed for Auto language detect. About \(spec.sizeLabel), stored only on this Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if downloading || models.downloadingID == spec.id {
                ProgressView(value: models.downloadProgress)
                Text("Downloading… \(Int(models.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if installed {
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button(installed ? "Downloaded" : "Download \(spec.title)") {
                Task { await downloadRecommended() }
            }
            .disabled(installed || downloading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func permissionCard(
        title: String,
        detail: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .font(.title2)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(actionTitle, action: action)
                    .disabled(granted)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func downloadRecommended() async {
        downloading = true
        errorMessage = nil
        let spec = WhisperModelSpec.recommended
        settings.selectedModelID = spec.id
        do {
            try await models.download(spec)
            await transcription.prewarm(modelID: spec.id)
            pipeline.refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
        downloading = false
    }
}
