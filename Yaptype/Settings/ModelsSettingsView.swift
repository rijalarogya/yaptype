import SwiftUI

struct ModelsSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var transcription: TranscriptionService
    @EnvironmentObject private var pipeline: DictationPipeline
    @EnvironmentObject private var rewrite: RewriteService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: AppPage.models.title, subtitle: AppPage.models.subtitle)

                if models.installedIDs.isEmpty {
                    YaptypeCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No models downloaded")
                                .font(.system(size: 16))
                                .foregroundStyle(YaptypeTheme.ink)
                            Text("One click downloads Large v3 Turbo, about \(WhisperModelSpec.recommended.sizeLabel). It stays on this Mac.")
                                .font(.system(size: 13))
                                .foregroundStyle(YaptypeTheme.muted)
                            if models.downloadingID == WhisperModelSpec.recommended.id {
                                ProgressView(value: models.downloadProgress)
                                Text("Downloading… \(Int(models.downloadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(YaptypeTheme.muted)
                            } else {
                                OrangeButton(title: "Download Large v3 Turbo", symbol: "arrow.down.circle") {
                                    Task { await downloadRecommended() }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Speech recognition")
                        .font(.system(size: 18))
                        .foregroundStyle(YaptypeTheme.ink)
                    Text("Whisper models run locally on this Mac.")
                        .font(.system(size: 13))
                        .foregroundStyle(YaptypeTheme.muted)
                }

                YaptypeCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(WhisperModelSpec.multilingual.enumerated()), id: \.element.id) { index, spec in
                            modelRow(spec)
                            if index < WhisperModelSpec.multilingual.count - 1 {
                                Divider().overlay(YaptypeTheme.line).padding(.leading, 20)
                            }
                        }
                    }
                }
                Text("These models hear any language. Large v3 Turbo is the default.")
                    .font(.caption)
                    .foregroundStyle(YaptypeTheme.muted)
                if let error = models.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if settings.language == .en {
                    Text("English only")
                        .font(.system(size: 18))
                        .foregroundStyle(YaptypeTheme.ink)
                    YaptypeCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(WhisperModelSpec.englishOnlyModels.enumerated()), id: \.element.id) { index, spec in
                                modelRow(spec)
                                if index < WhisperModelSpec.englishOnlyModels.count - 1 {
                                    Divider().overlay(YaptypeTheme.line).padding(.leading, 20)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rewrite")
                        .font(.system(size: 18))
                        .foregroundStyle(YaptypeTheme.ink)
                    Text("Optional local model used to clean dictation when Apple Intelligence is unavailable.")
                        .font(.system(size: 13))
                        .foregroundStyle(YaptypeTheme.muted)
                }

                YaptypeCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MLXModelSpec.recommended.title)
                                .font(.system(size: 15))
                                .foregroundStyle(YaptypeTheme.ink)
                            Text("Local rewrite model")
                                .font(.caption)
                                .foregroundStyle(YaptypeTheme.muted)
                        }
                        Spacer()
                        StatusDot(ok: rewrite.mlxReady, label: rewrite.mlxReady ? "Downloaded" : "Not downloaded")
                        GhostButton(title: rewrite.mlxReady ? "Reload" : "Download") {
                            Task { await rewrite.prepareMLX() }
                        }
                        .disabled(rewrite.mlxLoading)
                    }
                    Text("Used only when local rewriting is enabled.")
                        .font(.caption)
                        .foregroundStyle(YaptypeTheme.muted)
                    if rewrite.mlxLoading {
                        ProgressView(value: rewrite.mlxProgress)
                    }
                    if let error = rewrite.lastError {
                        Text(error).font(.caption).foregroundStyle(.orange)
                    }
                }

                YaptypeCard {
                    HStack {
                        Label("Installed model storage", systemImage: "internaldrive")
                            .foregroundStyle(YaptypeTheme.ink)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: models.installedStorageBytes(), countStyle: .file))
                            .foregroundStyle(YaptypeTheme.muted)
                    }
                    .font(.system(size: 13.5))
                }
            }
            .padding(28)
        }
        .background(YaptypeTheme.canvas)
        .onAppear {
            models.refreshInstalled()
            pipeline.ensureCompatibleModel()
        }
    }

    private func modelRow(_ spec: WhisperModelSpec) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(spec.title)
                        .font(.system(size: 15))
                        .foregroundStyle(YaptypeTheme.ink)
                    if spec.recommended {
                        Text("Recommended")
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(YaptypeTheme.orangeSoft, in: Capsule())
                            .foregroundStyle(YaptypeTheme.orange)
                    }
                }
                Text("\(spec.sizeLabel) · \(spec.subtitle)")
                    .font(.caption)
                    .foregroundStyle(YaptypeTheme.muted)
                if settings.selectedModelID == spec.id, models.isInstalled(spec) {
                    StatusDot(ok: true, label: "In use")
                } else if !models.isInstalled(spec) {
                    Text("Not downloaded")
                        .font(.caption)
                        .foregroundStyle(YaptypeTheme.muted)
                }
            }
            Spacer()
            if models.downloadingID == spec.id {
                ProgressView(value: models.downloadProgress)
                    .frame(width: 90)
            } else if models.isInstalled(spec) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(YaptypeTheme.green)
                if settings.selectedModelID != spec.id, spec.supports(settings.language) {
                    GhostButton(title: "Use") {
                        settings.selectedModelID = spec.id
                        Task {
                            await transcription.prewarm(modelID: spec.id)
                            pipeline.refreshStatus()
                        }
                    }
                }
                GhostButton(title: "Remove") {
                    try? models.delete(spec)
                    pipeline.ensureCompatibleModel()
                    pipeline.refreshStatus()
                }
            } else {
                GhostButton(title: "Download") {
                    Task {
                        do {
                            try await models.download(spec)
                            if settings.selectedModelID == spec.id || !models.installedIDs.contains(settings.selectedModelID) {
                                settings.selectedModelID = spec.id
                                await transcription.prewarm(modelID: spec.id)
                            }
                            pipeline.ensureCompatibleModel()
                            pipeline.refreshStatus()
                        } catch {
                            models.lastError = error.localizedDescription
                        }
                    }
                }
                .disabled(models.downloadingID != nil)
            }
        }
        .padding(16)
    }

    private func downloadRecommended() async {
        let spec = WhisperModelSpec.recommended
        do {
            try await models.download(spec)
            settings.selectedModelID = spec.id
            await transcription.prewarm(modelID: spec.id)
            pipeline.ensureCompatibleModel()
            pipeline.refreshStatus()
        } catch {
            models.lastError = error.localizedDescription
        }
    }
}
