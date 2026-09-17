import AppKit
import SwiftUI

@MainActor
final class HUDController {
    static let shared = HUDController()

    private var panel: NSPanel?
    private var host: NSHostingView<RecordingHUD>?
    private var model = HUDModel()

    func show(phase: DictationPhase, level: Float) {
        model.phase = phase
        model.level = level
        if panel == nil {
            makePanel()
        }
        position()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        model.phase = .idle
        model.level = 0
    }

    private func makePanel() {
        let view = NSHostingView(rootView: RecordingHUD(model: model))
        view.frame = NSRect(x: 0, y: 0, width: 280, height: 88)
        host = view

        let panel = NSPanel(
            contentRect: view.frame,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = view
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        self.panel = panel
    }

    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let x = screen.visibleFrame.midX - size.width / 2
        let y = screen.visibleFrame.minY + 28
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

@MainActor
final class HUDModel: ObservableObject {
    @Published var phase: DictationPhase = .idle
    @Published var level: Float = 0
}

struct RecordingHUD: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(indicatorColor.opacity(0.18))
                    .frame(width: 42, height: 42)
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 12 + CGFloat(min(model.level, 1)) * 16, height: 12 + CGFloat(min(model.level, 1)) * 16)
                    .animation(.easeOut(duration: 0.08), value: model.level)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.phase.hudTitle)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var indicatorColor: Color {
        switch model.phase {
        case .recording: .red
        case .error: .orange
        default: Color.accentColor
        }
    }

    private var subtitle: String {
        switch model.phase {
        case .recording: "Release to transcribe · Esc to cancel"
        case .transcribing: "Running Whisper on-device"
        case .rewriting: "Cleaning up fillers and punctuation"
        case .inserting: "Pasting into the focused app"
        case .error(let message): message
        case .idle: "Ready"
        }
    }
}
