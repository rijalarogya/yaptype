import AppKit
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var pipeline: DictationPipeline
    @EnvironmentObject private var transcription: TranscriptionService
    @EnvironmentObject private var rewrite: RewriteService
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var permissions: PermissionService
    @ObservedObject private var hotkey = HotkeyService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    PageHeader(title: AppPage.diagnostics.title, subtitle: AppPage.diagnostics.subtitle)
                    Spacer()
                    GhostButton(title: "Copy report") {
                        Clipboard.copy(report)
                    }
                }

                HStack(spacing: 12) {
                    diagnosticChip("Whisper Ready", ok: transcription.isReady, on: "Ready", off: transcription.isLoading ? "Loading" : "No")
                    diagnosticChip("Permissions", ok: permissions.accessibilityGranted && permissions.microphoneGranted, on: "Granted", off: "Missing")
                    diagnosticChip("Hotkey", ok: hotkey.tapRunning, on: "Running", off: "Stopped")
                }

                YaptypeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Last take", systemImage: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 16))
                        Text("Performance from your most recent dictation.")
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                        metric("Audio", String(format: "%.1fs", pipeline.lastTiming.audioSeconds))
                        metric("Transcribe", "\(Int(pipeline.lastTiming.transcribeMs)) ms")
                        metric("Rewrite", "\(Int(pipeline.lastTiming.rewriteMs)) ms")
                        metric("Insert", "\(Int(pipeline.lastTiming.insertMs)) ms")
                        Divider().overlay(YaptypeTheme.line)
                        metric("Total", "\(Int(pipeline.lastTiming.totalMs)) ms", emphasize: true)
                    }
                }

                YaptypeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Runtime", systemImage: "gearshape")
                            .font(.system(size: 16))
                        Text("Current local model and permission status.")
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                        metric("Whisper model", whisperModelLabel)
                        labeledStatus("Whisper ready", ok: transcription.isReady)
                        metric("Rewrite engine", rewrite.lastEngineName)
                        labeledStatus("Accessibility", ok: permissions.accessibilityGranted)
                        labeledStatus("Input Monitoring", ok: permissions.inputMonitoringGranted)
                        labeledStatus("Hotkey tap", ok: hotkey.tapRunning, on: "Running", off: "Stopped")
                        metric("Installed models", "\(models.installedIDs.count)")
                    }
                }

                YaptypeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Target", systemImage: "scope")
                            .font(.system(size: 16))
                        Text("On Apple Silicon with Large v3 Turbo prewarmed, a short utterance should land in the focused field within about a second.")
                            .font(.system(size: 13))
                            .foregroundStyle(YaptypeTheme.muted)
                    }
                }
            }
            .padding(28)
        }
        .background(YaptypeTheme.canvas)
    }

    private var whisperModelLabel: String {
        let loaded = transcription.loadedModelID
        if let loaded, models.installedIDs.contains(loaded) {
            return WhisperModelSpec.spec(for: loaded)?.title ?? loaded
        }
        if models.installedIDs.contains(settings.selectedModelID) {
            return WhisperModelSpec.spec(for: settings.selectedModelID)?.title ?? settings.selectedModelID
        }
        return "Not downloaded yet"
    }

    private func diagnosticChip(_ title: String, ok: Bool, on: String, off: String) -> some View {
        YaptypeCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(YaptypeTheme.muted)
                StatusDot(ok: ok, label: ok ? on : off)
            }
        }
    }

    private func metric(_ title: String, _ value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(YaptypeTheme.ink)
            Spacer()
            Text(value)
                .foregroundStyle(emphasize ? YaptypeTheme.ink : YaptypeTheme.muted)
                .fontWeight(emphasize ? .medium : .regular)
        }
        .font(.system(size: 13.5))
        .padding(.vertical, 4)
    }

    private func labeledStatus(_ title: String, ok: Bool, on: String = "Yes", off: String = "No") -> some View {
        HStack {
            Text(title)
                .foregroundStyle(YaptypeTheme.ink)
            Spacer()
            StatusDot(ok: ok, label: ok ? on : off)
        }
        .font(.system(size: 13.5))
        .padding(.vertical, 4)
    }

    private var report: String {
        """
        Yaptype diagnostics
        Whisper: \(whisperModelLabel) ready=\(transcription.isReady)
        Rewrite: \(rewrite.lastEngineName)
        Last take: audio \(String(format: "%.1fs", pipeline.lastTiming.audioSeconds)), total \(Int(pipeline.lastTiming.totalMs)) ms
        Accessibility: \(permissions.accessibilityGranted)
        Input Monitoring: \(permissions.inputMonitoringGranted)
        Hotkey: \(hotkey.tapRunning)
        """
    }
}
