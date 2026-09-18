import SwiftUI

struct FileTranscriptViewer: View {
    let item: HistoryItem
    var onClose: () -> Void

    @State private var showTimestamps: Bool

    init(item: HistoryItem, defaultTimestamps: Bool, onClose: @escaping () -> Void) {
        self.item = item
        self.onClose = onClose
        let wantsTimestamps = defaultTimestamps && item.hasTimestamps
        _showTimestamps = State(initialValue: wantsTimestamps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                GhostButton(title: "Back", symbol: "chevron.left", action: onClose)
                VStack(alignment: .leading, spacing: 2) {
                    Text("View transcription")
                        .font(.system(size: 22))
                        .foregroundStyle(YaptypeTheme.ink)
                    Text(item.displayTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(YaptypeTheme.muted)
                        .lineLimit(1)
                }
                Spacer()
                OrangeButton(title: "Copy", symbol: "doc.on.doc") {
                    Clipboard.copy(displayedText)
                }
            }

            HStack(spacing: 8) {
                modeChip(title: "Without timestamps", selected: !showTimestamps) {
                    showTimestamps = false
                }
                modeChip(title: "With timestamps", selected: showTimestamps) {
                    showTimestamps = true
                }
                if !item.hasTimestamps {
                    Text("No timestamps were saved for this file.")
                        .font(.caption)
                        .foregroundStyle(YaptypeTheme.muted)
                }
                Spacer()
                Text("\(TimeFormat.compact(item.audioSeconds)) · \(item.modelTitle)")
                    .font(.caption)
                    .foregroundStyle(YaptypeTheme.muted)
            }

            YaptypeCard {
                ScrollView {
                    Text(displayedText.isEmpty ? "No text in this transcription." : displayedText)
                        .font(.system(size: 14))
                        .foregroundStyle(displayedText.isEmpty ? YaptypeTheme.muted : YaptypeTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(YaptypeTheme.canvas)
    }

    private var displayedText: String {
        item.transcript(withTimestamps: showTimestamps)
    }

    private func modeChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(selected ? YaptypeTheme.orange : YaptypeTheme.ink)
                .background(
                    Capsule().fill(selected ? YaptypeTheme.orangeSoft : Color.clear)
                )
                .overlay(
                    Capsule().stroke(selected ? Color.clear : YaptypeTheme.line)
                )
        }
        .buttonStyle(.plain)
    }
}
