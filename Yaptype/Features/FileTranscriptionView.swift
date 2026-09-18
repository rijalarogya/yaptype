import SwiftUI
import UniformTypeIdentifiers

struct FileTranscriptionView: View {
    @EnvironmentObject private var files: FileTranscriptionService
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var navigation: AppNavigation
    @State private var dropTargeted = false
    @State private var viewingItem: HistoryItem?

    var body: some View {
        if let viewingItem {
            FileTranscriptViewer(
                item: viewingItem,
                defaultTimestamps: files.includeTimestamps,
                onClose: { self.viewingItem = nil }
            )
            .id(viewingItem.id)
        } else {
            fileWorkspace
        }
    }

    private var fileWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: AppPage.fileTranscription.title, subtitle: AppPage.fileTranscription.subtitle)

            HStack(alignment: .top, spacing: 16) {
                YaptypeCard {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(YaptypeTheme.orangeSoft)
                                .frame(width: 64, height: 64)
                            Image(systemName: "doc.badge.arrow.up")
                                .font(.system(size: 22))
                                .foregroundStyle(YaptypeTheme.orange)
                        }
                        Text("Drop audio or video files here")
                            .font(.system(size: 18))
                            .foregroundStyle(YaptypeTheme.ink)
                        Text("or choose a file from your computer")
                            .font(.system(size: 13))
                            .foregroundStyle(YaptypeTheme.muted)
                        OrangeButton(title: "Choose file", symbol: "folder") {
                            files.chooseFile()
                        }
                        Text("MP3, WAV, M4A, MP4, MOV")
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                        Text("Files are processed locally on this Mac.")
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)

                        if let job = files.activeJob {
                            fileProgress(job)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(dropTargeted ? YaptypeTheme.orange : Color.clear, lineWidth: 2)
                )
                .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
                    handleDrop(providers)
                }

                YaptypeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transcription settings")
                            .font(.system(size: 16))
                            .foregroundStyle(YaptypeTheme.ink)
                        SettingsRow(title: "Language") {
                            MacPopupButton(
                                selection: $files.languageRaw,
                                options: TranscriptionLanguage.allCases.map { ($0.rawValue, $0.title) }
                            )
                            .frame(width: 150, height: 28)
                        }
                        Divider().overlay(YaptypeTheme.line)
                        SettingsRow(title: "Timestamps") {
                            MacPopupButton(
                                selection: $files.includeTimestamps,
                                options: [(true, "On"), (false, "Off")]
                            )
                            .frame(width: 150, height: 28)
                        }
                        Text("Language applies only to files. Timestamps is the default when you open a transcription.")
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                    }
                }
                .frame(width: 320)
            }

            YaptypeCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent transcriptions")
                            .font(.system(size: 16))
                            .foregroundStyle(YaptypeTheme.ink)
                        Spacer()
                        Button("View all") { navigation.go(.history) }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                    }
                    let items = history.items(kind: .file)
                    if items.isEmpty {
                        Text("Drop a file to transcribe it on this Mac.")
                            .font(.system(size: 13))
                            .foregroundStyle(YaptypeTheme.muted)
                    } else {
                        ForEach(Array(items.prefix(4))) { item in
                            HStack {
                                Image(systemName: "film")
                                    .foregroundStyle(YaptypeTheme.muted)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayTitle)
                                        .foregroundStyle(YaptypeTheme.ink)
                                    Text("\(TimeFormat.compact(item.audioSeconds)) · \(TimeFormat.relative(item.createdAt))")
                                        .foregroundStyle(YaptypeTheme.muted)
                                }
                                Spacer()
                                StatusDot(ok: true, label: "Completed")
                                GhostButton(title: "View transcription") {
                                    viewingItem = item
                                }
                                GhostButton(title: "Copy", symbol: "doc.on.doc") {
                                    Clipboard.copy(item.plainTranscript)
                                }
                            }
                            .font(.system(size: 13))
                            if item.id != items.prefix(4).last?.id {
                                Divider().overlay(YaptypeTheme.line)
                            }
                        }
                    }
                }
            }

            if let error = files.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(28)
        }
        .background(YaptypeTheme.canvas)
        .onAppear {
            if navigation.consumeFilePicker() {
                DispatchQueue.main.async {
                    files.chooseFile()
                }
            }
        }
        .onChange(of: navigation.pendingFileURL) { _, url in
            if let url {
                files.transcribe(url: url)
                navigation.pendingFileURL = nil
            }
        }
        .onChange(of: files.lastItem) { _, item in
            if let item {
                viewingItem = item
            }
        }
    }

    private func fileProgress(_ job: FileJob) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "doc")
                    .foregroundStyle(YaptypeTheme.muted)
                VStack(alignment: .leading, spacing: 6) {
                    Text(job.fileName)
                        .font(.system(size: 13))
                        .foregroundStyle(YaptypeTheme.ink)
                    ProgressView(value: job.progress)
                        .tint(YaptypeTheme.orange)
                }
                StatusDot(ok: job.state == .completed, label: progressLabel(job))
                Text(job.modelTitle)
                    .font(.caption)
                    .foregroundStyle(YaptypeTheme.muted)
            }
            if job.state == .completed, let item = files.lastItem, item.id == job.id {
                HStack(spacing: 8) {
                    OrangeButton(title: "View transcription") {
                        viewingItem = item
                    }
                    GhostButton(title: "Copy", symbol: "doc.on.doc") {
                        Clipboard.copy(item.plainTranscript)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func progressLabel(_ job: FileJob) -> String {
        switch job.state {
        case .idle: "Ready"
        case .decoding: "Preparing…"
        case .transcribing: "Transcribing…"
        case .completed: "Completed"
        case .failed: "Failed"
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let value = item as? URL {
                url = value
            } else {
                url = nil
            }
            guard let url else { return }
            Task { @MainActor in
                files.transcribe(url: url)
            }
        }
        return true
    }
}
