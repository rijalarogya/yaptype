import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var pipeline: DictationPipeline
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var permissions: PermissionService
    @EnvironmentObject private var transcription: TranscriptionService
    @EnvironmentObject private var rewrite: RewriteService
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var navigation: AppNavigation
    @EnvironmentObject private var notes: NoteTakerService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: AppPage.home.title, subtitle: AppPage.home.subtitle)

                YaptypeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(homeStatusTitle)
                            .font(.system(size: 22))
                            .foregroundStyle(YaptypeTheme.ink)
                        Text("Speak here to try Yaptype, or hold your hotkey to type into another app.")
                            .foregroundStyle(YaptypeTheme.muted)
                            .font(.system(size: 13.5))

                        dictationField

                        HStack(spacing: 10) {
                            OrangeButton(
                                title: dictationButtonTitle,
                                symbol: dictationButtonSymbol
                            ) {
                                toggleDictation()
                            }
                            MacPopupButton(
                                selection: settings.binding(\.languageRaw),
                                options: TranscriptionLanguage.allCases.map { ($0.rawValue, $0.title) }
                            )
                            .frame(width: 128, height: 28)
                            .onChange(of: settings.languageRaw) { _, _ in
                                pipeline.ensureCompatibleModel()
                                pipeline.refreshStatus()
                            }
                            MacPopupButton(
                                selection: settings.binding(\.hotkeyRaw),
                                options: HotkeyPreset.allCases.map { ($0.rawValue, $0.title) }
                            )
                            .frame(width: 176, height: 28)
                            .onChange(of: settings.hotkeyRaw) { _, _ in
                                pipeline.restartHotkey()
                            }
                            MacPopupButton(
                                selection: settings.binding(\.selectedModelID),
                                options: homeModelOptions,
                                placeholder: "None downloaded",
                                isEnabled: { models.installedIDs.contains($0) },
                                onSelect: applyHomeModel
                            )
                            .frame(width: 188, height: 28)
                            .disabled(pipeline.phase.isBusy)
                        }
                        if models.installedIDs.isEmpty {
                            Text("Download a Whisper model in Models, then switch it here.")
                                .font(.caption)
                                .foregroundStyle(YaptypeTheme.muted)
                        }

                        Divider().overlay(YaptypeTheme.line)

                        HStack {
                            homeMetric(
                                symbol: "gearshape",
                                title: "Model",
                                value: modelMetric
                            )
                            Spacer()
                            homeMetric(
                                symbol: "sparkles",
                                title: "Rewrite",
                                value: settings.rewriteEnabled ? "On" : "Off"
                            )
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Microphone")
                                    .font(.caption)
                                    .foregroundStyle(YaptypeTheme.muted)
                                StatusDot(ok: permissions.microphoneGranted, label: permissions.microphoneGranted ? "Ready" : "Missing")
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick actions")
                        .font(.system(size: 18))
                        .foregroundStyle(YaptypeTheme.ink)
                    HStack(alignment: .top, spacing: 16) {
                        YaptypeCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Note Taker", systemImage: "doc.text")
                                    .font(.system(size: 16))
                                    .foregroundStyle(YaptypeTheme.ink)
                                Text("Record meetings, conversations, or ideas and keep the transcript in one place.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(YaptypeTheme.muted)
                                OrangeButton(
                                    title: notes.isActive ? "Open note" : "Start a note",
                                    symbol: "mic.fill"
                                ) {
                                    navigation.startNote()
                                    if notes.phase == .idle {
                                        notes.start()
                                    }
                                }
                            }
                        }
                        YaptypeCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Transcribe a file", systemImage: "doc")
                                    .font(.system(size: 16))
                                    .foregroundStyle(YaptypeTheme.ink)
                                Text("Drop an audio or video file and turn it into text.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(YaptypeTheme.muted)
                                GhostButton(title: "Choose file", symbol: "square.and.arrow.up") {
                                    navigation.chooseFile()
                                }
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    YaptypeCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent")
                                    .font(.system(size: 16))
                                    .foregroundStyle(YaptypeTheme.ink)
                                Spacer()
                                Button("View all history") {
                                    navigation.go(.history)
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(YaptypeTheme.muted)
                            }
                            if history.items.isEmpty {
                                Text("No takes yet. Hold your hotkey or start a note.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(YaptypeTheme.muted)
                            } else {
                                ForEach(Array(history.items.prefix(3))) { item in
                                    Button {
                                        navigation.go(.history)
                                    } label: {
                                        HStack {
                                            Image(systemName: item.kind.symbol)
                                                .foregroundStyle(YaptypeTheme.muted)
                                            Text(item.displayText)
                                                .lineLimit(1)
                                                .foregroundStyle(YaptypeTheme.ink)
                                            Spacer()
                                            Text(TimeFormat.relative(item.createdAt))
                                                .foregroundStyle(YaptypeTheme.muted)
                                            Text(item.modelTitle)
                                                .foregroundStyle(YaptypeTheme.muted)
                                        }
                                        .font(.system(size: 13))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if item.id != Array(history.items.prefix(3)).last?.id {
                                        Divider().overlay(YaptypeTheme.line)
                                    }
                                }
                            }
                        }
                    }

                    YaptypeCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("System status")
                                .font(.system(size: 16))
                                .foregroundStyle(YaptypeTheme.ink)
                            statusLine("Microphone", ok: permissions.microphoneGranted, on: "Ready", off: "Missing")
                            statusLine("Accessibility", ok: permissions.accessibilityGranted, on: "Granted", off: "Missing")
                            statusLine("Input Monitoring", ok: permissions.inputMonitoringGranted, on: "Granted", off: "Missing")
                            statusLine(
                                "Model",
                                ok: transcription.isReady || models.installedIDs.contains(settings.selectedModelID),
                                on: transcription.isReady ? "Loaded" : "Installed",
                                off: "Needed"
                            )
                        }
                    }
                    .frame(width: 260)
                }
            }
            .padding(28)
        }
        .background(YaptypeTheme.canvas)
        .onAppear {
            models.refreshInstalled()
        }
    }

    private var dictationField: some View {
        ZStack(alignment: .topLeading) {
            if pipeline.scratchText.isEmpty {
                Text(scratchPlaceholder)
                    .font(.system(size: 14))
                    .foregroundStyle(YaptypeTheme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
            TextEditor(text: Binding(
                get: { pipeline.scratchText },
                set: { pipeline.scratchText = $0 }
            ))
                .font(.system(size: 14))
                .foregroundStyle(YaptypeTheme.ink)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: 44, maxHeight: 56)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .background(YaptypeTheme.canvas, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(YaptypeTheme.line, lineWidth: 1)
        )
    }

    private var scratchPlaceholder: String {
        switch pipeline.phase {
        case .recording: "Listening…"
        case .preparing: "Preparing the model…"
        case .transcribing: "Transcribing…"
        case .rewriting: "Cleaning…"
        case .inserting: "Adding text…"
        case .error(let message): message
        case .idle: "Your dictation will appear here."
        }
    }

    private var homeStatusTitle: String {
        switch pipeline.phase {
        case .idle: "Ready to dictate"
        case .recording: "Listening…"
        case .preparing: "Preparing model…"
        case .transcribing: "Transcribing…"
        case .rewriting: "Cleaning…"
        case .inserting: "Adding text…"
        case .error: "Couldn’t start"
        }
    }

    private var dictationButtonTitle: String {
        switch pipeline.phase {
        case .recording: "Stop dictating"
        case .preparing, .transcribing, .rewriting, .inserting: "Cancel"
        default: "Start Dictating"
        }
    }

    private var dictationButtonSymbol: String {
        switch pipeline.phase {
        case .recording: "stop.fill"
        case .preparing, .transcribing, .rewriting, .inserting: "xmark"
        default: "mic.fill"
        }
    }

    private var homeModelOptions: [(value: String, title: String)] {
        WhisperModelSpec.all
            .filter { $0.supports(settings.language) }
            .map { ($0.id, $0.title) }
    }

    private func applyHomeModel(_ id: String) {
        guard models.installedIDs.contains(id) else { return }
        settings.objectWillChange.send()
        settings.selectedModelID = id
        Task {
            await transcription.prewarm(modelID: id)
            pipeline.refreshStatus()
        }
    }

    private var modelMetric: String {
        if models.installedIDs.isEmpty {
            return "None downloaded"
        }
        return WhisperModelSpec.spec(for: settings.selectedModelID)?.title ?? settings.selectedModelID
    }

    private func homeMetric(symbol: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(YaptypeTheme.muted)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(YaptypeTheme.ink)
        }
    }

    private func statusLine(_ title: String, ok: Bool, on: String, off: String) -> some View {
        HStack {
            Label(title, systemImage: title == "Microphone" ? "mic" : (title == "Model" ? "square.stack.3d.up" : "checkmark.shield"))
                .foregroundStyle(YaptypeTheme.ink)
            Spacer()
            StatusDot(ok: ok, label: ok ? on : off)
        }
        .font(.system(size: 13))
    }

    private func toggleDictation() {
        switch pipeline.phase {
        case .recording:
            pipeline.finishRecording()
        case .preparing, .transcribing, .rewriting, .inserting:
            pipeline.cancel()
        default:
            pipeline.beginRecording(into: .scratch)
        }
    }
}
