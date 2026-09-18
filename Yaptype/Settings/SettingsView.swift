import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            ModelsSettingsView()
                .tabItem { Label("Models", systemImage: "square.stack.3d.up") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
            DiagnosticsView()
                .tabItem { Label("Diagnostics", systemImage: "speedometer") }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pipeline: DictationPipeline
    @EnvironmentObject private var permissions: PermissionService
    @EnvironmentObject private var rewrite: RewriteService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: AppPage.general.title, subtitle: AppPage.general.subtitle)

                settingsCard("Dictation", symbol: "mic") {
                    SettingsRow(title: "Hotkey") {
                        MacPopupButton(
                            selection: settings.binding(\.hotkeyRaw),
                            options: HotkeyPreset.allCases.map { ($0.rawValue, $0.title) }
                        )
                        .frame(width: 200, height: 28)
                    }
                    .onChange(of: settings.hotkeyRaw) { _, _ in
                        pipeline.restartHotkey()
                    }
                    Divider().overlay(YaptypeTheme.line)
                    SettingsRow(title: "Language", subtitle: settings.language == .auto
                                ? "Hears whatever you speak."
                                : "Pin a language only if short takes misfire.") {
                        MacPopupButton(
                            selection: settings.binding(\.languageRaw),
                            options: TranscriptionLanguage.allCases.map { ($0.rawValue, $0.title) }
                        )
                        .frame(width: 200, height: 28)
                    }
                    .onChange(of: settings.languageRaw) { _, _ in
                        pipeline.ensureCompatibleModel()
                        pipeline.refreshStatus()
                    }
                }

                settingsCard("Rewrite", symbol: "sparkles") {
                    SettingsRow(title: "Fix small grammar") {
                        Toggle("", isOn: $settings.rewriteEnabled).labelsHidden()
                    }
                    Divider().overlay(YaptypeTheme.line)
                    SettingsRow(title: "Prefer Apple Intelligence when available") {
                        Toggle("", isOn: $settings.preferAppleIntelligence).labelsHidden()
                    }
                    Divider().overlay(YaptypeTheme.line)
                    SettingsRow(title: "Apple Intelligence") {
                        StatusDot(ok: rewrite.appleIntelligenceAvailable, label: rewrite.appleIntelligenceAvailable ? "Available" : "Not available")
                    }
                    Divider().overlay(YaptypeTheme.line)
                    SettingsRow(title: "Local Qwen model") {
                        StatusDot(ok: rewrite.mlxReady, label: rewriteStatus)
                    }
                    Text("Fixes small grammar. Does not change how you said it.")
                        .font(.caption)
                        .foregroundStyle(YaptypeTheme.muted)
                    if rewrite.mlxLoading {
                        ProgressView(value: rewrite.mlxProgress)
                        Text("Downloading… \(Int(rewrite.mlxProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                    }
                    GhostButton(title: rewrite.mlxReady ? "Reload local rewrite model" : "Download local rewrite model") {
                        Task { await rewrite.prepareMLX() }
                    }
                    .disabled(rewrite.mlxLoading)
                    if let error = rewrite.lastError {
                        Text(error).font(.caption).foregroundStyle(.orange)
                    }
                }

                settingsCard("Permissions", symbol: "checkmark.shield") {
                    SettingsRow(title: "This copy") {
                        Text(permissions.runningPath)
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                            .textSelection(.enabled)
                            .lineLimit(1)
                    }
                    Divider().overlay(YaptypeTheme.line)
                    SettingsRow(title: "Microphone") {
                        StatusDot(ok: permissions.microphoneGranted, label: permissions.microphoneGranted ? "Granted" : "Missing")
                    }
                    Divider().overlay(YaptypeTheme.line)
                    SettingsRow(title: "Accessibility") {
                        StatusDot(ok: permissions.accessibilityGranted, label: permissions.accessibilityGranted ? "Granted" : "Missing")
                    }
                    Divider().overlay(YaptypeTheme.line)
                    SettingsRow(title: "Input Monitoring") {
                        StatusDot(ok: permissions.inputMonitoringGranted, label: permissions.inputMonitoringGranted ? "Granted" : "Missing")
                    }
                    HStack {
                        GhostButton(title: "Microphone settings") { permissions.openMicrophoneSettings() }
                        GhostButton(title: "Accessibility settings") { permissions.openAccessibilitySettings() }
                        GhostButton(title: "Input Monitoring") { permissions.openInputMonitoringSettings() }
                    }
                    if !permissions.accessibilityGranted || !permissions.inputMonitoringGranted {
                        OrangeButton(title: "Quit & Reopen Yaptype") {
                            permissions.relaunch()
                        }
                    }
                }

                settingsCard("System", symbol: "power") {
                    SettingsRow(title: "Open Yaptype at login") {
                        Toggle("", isOn: $settings.launchAtLogin).labelsHidden()
                    }
                    .onChange(of: settings.launchAtLogin) { _, _ in
                        settings.applyLaunchAtLogin()
                    }
                    Text(pipeline.statusMessage)
                        .font(.caption)
                        .foregroundStyle(YaptypeTheme.muted)
                }
            }
            .padding(28)
        }
        .background(YaptypeTheme.canvas)
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

    private func settingsCard<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        YaptypeCard {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(YaptypeTheme.ink)
                    .padding(.bottom, 8)
                content()
            }
        }
    }
}
