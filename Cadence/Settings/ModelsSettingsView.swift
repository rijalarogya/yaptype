import SwiftUI

struct ModelsSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var transcription: TranscriptionService
    @EnvironmentObject private var pipeline: DictationPipeline

    var body: some View {
        List {
            Section("Whisper models") {
                ForEach(WhisperModelSpec.all) { spec in
                    modelRow(spec)
                }
            }
            Section("Local rewrite") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(MLXModelSpec.recommended.title)
                        .font(.headline)
                    Text(MLXModelSpec.recommended.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(MLXModelSpec.recommended.sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { models.refreshInstalled() }
    }

    private func modelRow(_ spec: WhisperModelSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(spec.title).font(.headline)
                        if spec.recommended {
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(spec.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(spec.sizeLabel + (spec.englishOnly ? " · English" : " · Multilingual"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if models.downloadingID == spec.id {
                    ProgressView(value: models.downloadProgress)
                        .frame(width: 84)
                } else if models.isInstalled(spec) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack {
                if settings.selectedModelID == spec.id {
                    Label("In use", systemImage: "mic.fill")
                        .font(.caption)
                } else if models.isInstalled(spec) {
                    Button("Use this model") {
                        settings.selectedModelID = spec.id
                        Task {
                            await transcription.prewarm(modelID: spec.id)
                            pipeline.refreshStatus()
                        }
                    }
                }

                Spacer()

                if models.isInstalled(spec) {
                    Button("Remove", role: .destructive) {
                        try? models.delete(spec)
                        if settings.selectedModelID == spec.id {
                            settings.selectedModelID = models.installedIDs.first ?? WhisperModelSpec.recommended.id
                        }
                        pipeline.refreshStatus()
                    }
                } else {
                    Button("Download") {
                        Task {
                            do {
                                try await models.download(spec)
                                if settings.selectedModelID == spec.id {
                                    await transcription.prewarm(modelID: spec.id)
                                }
                                pipeline.refreshStatus()
                            } catch {
                                models.lastError = error.localizedDescription
                            }
                        }
                    }
                    .disabled(models.downloadingID != nil)
                }
            }

            if models.downloadingID == spec.id {
                Text("Downloading… \(Int(models.downloadProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let error = models.lastError, models.downloadingID == spec.id {
                Text(error).font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
    }
}
