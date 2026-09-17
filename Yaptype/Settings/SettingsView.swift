import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            ModelsSettingsView()
                .tabItem { Label("Models", systemImage: "square.stack.3d.up") }
            HistorySettingsView()
                .tabItem { Label("History", systemImage: "clock") }
            DiagnosticsView()
                .tabItem { Label("Diagnostics", systemImage: "speedometer") }
        }
        .padding(8)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pipeline: DictationPipeline
    @EnvironmentObject private var permissions: PermissionService
    @EnvironmentObject private var rewrite: RewriteService

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Hotkey", selection: $settings.hotkeyRaw) {
                    ForEach(HotkeyPreset.allCases) { preset in
                        Text(preset.title).tag(preset.rawValue)
                    }
                }
                .onChange(of: settings.hotkeyRaw) { _, _ in
                    pipeline.restartHotkey()
                }

                Picker("Language", selection: $settings.languageRaw) {
                    ForEach(TranscriptionLanguage.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }
            }

            Section("Rewrite") {
                Toggle("Polish dictation into written prose", isOn: $settings.rewriteEnabled)
                Toggle("Prefer Apple Intelligence when available", isOn: $settings.preferAppleIntelligence)
                LabeledContent("Apple Intelligence") {
                    Text(rewrite.appleIntelligenceAvailable ? "Available" : "Not available")
                        .foregroundStyle(rewrite.appleIntelligenceAvailable ? .green : .secondary)
                }
                LabeledContent("Local Qwen model") {
                    Text(rewriteStatus)
                        .foregroundStyle(rewrite.mlxReady ? .green : .secondary)
                }
                Text("Optional. Dictation still polishes with Apple Intelligence or local rules if Qwen cannot run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if rewrite.mlxLoading {
                    ProgressView(value: rewrite.mlxProgress)
                    Text("Downloading… \(Int(rewrite.mlxProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(rewrite.mlxReady ? "Reload local rewrite model" : "Download local rewrite model") {
                    Task { await rewrite.prepareMLX() }
                }
                .disabled(rewrite.mlxLoading)
                if let error = rewrite.lastError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Permissions") {
                LabeledContent("This copy") {
                    Text(permissions.runningPath)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                LabeledContent("Microphone") {
                    status(permissions.microphoneGranted)
                }
                LabeledContent("Accessibility") {
                    status(permissions.accessibilityGranted)
                }
                LabeledContent("Input Monitoring") {
                    status(permissions.inputMonitoringGranted)
                }
                if let hint = permissions.hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Microphone settings") { permissions.openMicrophoneSettings() }
                    Button("Accessibility settings") { permissions.openAccessibilitySettings() }
                    Button("Input Monitoring") { permissions.openInputMonitoringSettings() }
                }
                if !permissions.accessibilityGranted || !permissions.inputMonitoringGranted {
                    Button("Quit & Reopen Yaptype") {
                        permissions.relaunch()
                    }
                }
            }

            Section("System") {
                Toggle("Open Yaptype at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, _ in
                        settings.applyLaunchAtLogin()
                    }
                Text(pipeline.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            permissions.refresh()
            rewrite.refreshAvailability()
        }
    }

    private var rewriteStatus: String {
        if rewrite.mlxCanRun { return "Ready" }
        if rewrite.mlxReady { return "Downloaded" }
        return "Not downloaded"
    }

    private func status(_ granted: Bool) -> some View {
        Text(granted ? "Granted" : "Missing")
            .foregroundStyle(granted ? .green : .orange)
    }
}
