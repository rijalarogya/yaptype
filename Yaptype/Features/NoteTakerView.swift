import SwiftUI

struct NoteTakerView: View {
    @EnvironmentObject private var notes: NoteTakerService
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var permissions: PermissionService
    @EnvironmentObject private var navigation: AppNavigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: AppPage.noteTaker.title, subtitle: AppPage.noteTaker.subtitle)

            YaptypeCard {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(YaptypeTheme.orangeSoft)
                            .frame(width: 54, height: 54)
                        Image(systemName: "mic.fill")
                            .foregroundStyle(YaptypeTheme.orange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        StatusDot(
                            ok: notes.phase == .recording || notes.phase == .paused,
                            label: statusLabel
                        )
                        Text(TimeFormat.clock(notes.elapsedSeconds))
                            .font(.system(size: 28, design: .rounded))
                            .foregroundStyle(YaptypeTheme.ink)
                        Text(permissions.microphoneGranted ? "MacBook Microphone" : "Microphone needed")
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                    }
                    LiveWaveform(level: notes.audioLevel, active: notes.phase == .recording)
                        .frame(height: 42)
                        .padding(.horizontal, 12)
                    Spacer()
                    if notes.phase == .idle {
                        OrangeButton(title: "Start recording", symbol: "record.circle") {
                            notes.start()
                        }
                    } else {
                        HStack(spacing: 8) {
                            OrangeButton(
                                title: notes.phase == .paused ? "Resume" : "Stop recording",
                                symbol: notes.phase == .paused ? "play.fill" : "stop.fill"
                            ) {
                                if notes.phase == .paused {
                                    notes.resume()
                                } else if notes.phase == .recording {
                                    notes.stop()
                                }
                            }
                            Button {
                                if notes.phase == .recording {
                                    notes.pause()
                                } else if notes.phase == .paused {
                                    notes.resume()
                                }
                            } label: {
                                Image(systemName: notes.phase == .paused ? "play.fill" : "pause.fill")
                                    .foregroundStyle(YaptypeTheme.ink)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().stroke(YaptypeTheme.line))
                            }
                            .buttonStyle(.plain)
                            .disabled(notes.phase == .transcribing || notes.phase == .cleaning)
                        }
                    }
                    StatusDot(ok: notes.phase == .recording, label: notes.phase == .recording ? "Listening" : "Idle")
                }
                if let error = notes.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                YaptypeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Live transcript")
                                .font(.system(size: 16))
                            Spacer()
                            StatusDot(ok: notes.phase == .recording, label: notes.phase == .recording ? "Transcribing live" : "Paused")
                            GhostButton(title: "Copy", symbol: "doc.on.doc") {
                                notes.copyTranscript()
                            }
                        }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                if notes.segments.isEmpty && notes.transcript.isEmpty {
                                    Text("Start recording to capture a live transcript.")
                                        .foregroundStyle(YaptypeTheme.muted)
                                        .font(.system(size: 13))
                                } else if notes.segments.isEmpty {
                                    Text(notes.transcript)
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(YaptypeTheme.ink)
                                } else {
                                    ForEach(notes.segments) { segment in
                                        HStack(alignment: .top, spacing: 12) {
                                            Text(segment.timestampLabel)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundStyle(YaptypeTheme.muted)
                                                .frame(width: 44, alignment: .leading)
                                            Text(segment.text)
                                                .font(.system(size: 13.5))
                                                .foregroundStyle(YaptypeTheme.ink)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(minHeight: 220)
                    }
                }

                YaptypeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Notes")
                            Spacer()
                            Button("Clean notes") { notes.cleanNotes() }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(YaptypeTheme.muted)
                                .disabled(notes.transcript.isEmpty || notes.isCleaning)
                        }
                        .font(.system(size: 16))

                        ScrollView {
                            Text(notes.notesText.isEmpty ? "Key points and action items will appear here." : notes.notesText)
                                .font(.system(size: 13.5))
                                .foregroundStyle(notes.notesText.isEmpty ? YaptypeTheme.muted : YaptypeTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 180)
                        HStack {
                            Spacer()
                            GhostButton(title: "Copy notes", symbol: "doc.on.doc") {
                                notes.copyNotes()
                            }
                        }
                    }
                }
                .frame(width: 320)
            }

            YaptypeCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent notes")
                            .font(.system(size: 16))
                        Spacer()
                        Button("View all") { navigation.go(.history) }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(YaptypeTheme.muted)
                    }
                    let notesItems = history.items(kind: .note)
                    if notesItems.isEmpty {
                        Text("Saved notes will show up here.")
                            .font(.system(size: 13))
                            .foregroundStyle(YaptypeTheme.muted)
                    } else {
                        ForEach(Array(notesItems.prefix(3))) { item in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(YaptypeTheme.muted)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayTitle)
                                        .foregroundStyle(YaptypeTheme.ink)
                                    Text(item.previewText)
                                        .lineLimit(1)
                                        .foregroundStyle(YaptypeTheme.muted)
                                }
                                Spacer()
                                Text("\(TimeFormat.relative(item.createdAt)) · \(TimeFormat.compact(item.audioSeconds))")
                                    .foregroundStyle(YaptypeTheme.muted)
                            }
                            .font(.system(size: 13))
                        }
                    }
                }
            }
            }
        }
        .padding(28)
        .background(YaptypeTheme.canvas)
    }

    private var statusLabel: String {
        switch notes.phase {
        case .idle: "Ready"
        case .recording: "Recording"
        case .paused: "Paused"
        case .transcribing: "Transcribing"
        case .cleaning: "Cleaning notes"
        }
    }
}

struct LiveWaveform: View {
    var level: Float
    var active: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.08)) { timeline in
            let seed = active ? timeline.date.timeIntervalSinceReferenceDate : 0
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<32, id: \.self) { index in
                    Capsule()
                        .fill(YaptypeTheme.orange.opacity(active ? 0.9 : 0.25))
                        .frame(width: 3, height: barHeight(index: index, seed: seed))
                }
            }
        }
    }

    private func barHeight(index: Int, seed: TimeInterval) -> CGFloat {
        let wave = abs(sin(seed * 6 + Double(index) * 0.45))
        let boosted = CGFloat(max(0.08, level)) * 38 * CGFloat(0.35 + wave)
        return active ? max(6, boosted) : 6
    }
}
