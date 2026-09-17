import AppKit
import SwiftUI

struct HistorySettingsView: View {
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if history.items.isEmpty {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "mic",
                    description: Text("Hold your hotkey, speak, and Yaptype will keep a local history here.")
                )
            } else {
                List {
                    ForEach(history.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.displayText)
                                .font(.body)
                            if item.rawText != item.polishedText, !item.rawText.isEmpty {
                                Text("Spoken: \(item.rawText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                Text(item.modelID)
                                Text(item.rewriteEngine)
                                Text("\(Int(item.totalMs)) ms")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .contextMenu {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.displayText, forType: .string)
                            }
                            Button("Delete", role: .destructive) {
                                history.delete(item)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            history.delete(history.items[index])
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Clear history", role: .destructive) {
                    history.clear()
                }
                .disabled(history.items.isEmpty)
            }
            .padding(12)
        }
    }
}

struct DiagnosticsView: View {
    @EnvironmentObject private var pipeline: DictationPipeline
    @EnvironmentObject private var transcription: TranscriptionService
    @EnvironmentObject private var rewrite: RewriteService
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var permissions: PermissionService
    @ObservedObject private var hotkey = HotkeyService.shared

    var body: some View {
        Form {
            Section("Last take") {
                LabeledContent("Audio") {
                    Text(String(format: "%.1fs", pipeline.lastTiming.audioSeconds))
                }
                LabeledContent("Transcribe") {
                    Text("\(Int(pipeline.lastTiming.transcribeMs)) ms")
                }
                LabeledContent("Rewrite") {
                    Text("\(Int(pipeline.lastTiming.rewriteMs)) ms · \(pipeline.lastTiming.engine)")
                }
                LabeledContent("Insert") {
                    Text("\(Int(pipeline.lastTiming.insertMs)) ms")
                }
                LabeledContent("Total") {
                    Text("\(Int(pipeline.lastTiming.totalMs)) ms")
                }
            }

            Section("Runtime") {
                LabeledContent("Whisper model") { Text(settings.selectedModelID) }
                LabeledContent("Whisper ready") {
                    Text(transcription.isReady ? "Yes" : (transcription.isLoading ? "Loading…" : "No"))
                }
                LabeledContent("Rewrite engine") { Text(rewrite.lastEngineName) }
                LabeledContent("Accessibility") {
                    Text(permissions.accessibilityGranted ? "Yes" : "No")
                }
                LabeledContent("Input Monitoring") {
                    Text(permissions.inputMonitoringGranted ? "Yes" : "No")
                }
                LabeledContent("Hotkey tap") {
                    Text(hotkey.tapRunning ? "Running" : "Stopped")
                }
                LabeledContent("Installed models") {
                    Text("\(models.installedIDs.count)")
                }
            }

            Section("Target") {
                Text("On Apple Silicon with Large v3 Turbo prewarmed, a short utterance should land in the focused field within about a second.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
