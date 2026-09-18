import AppKit
import SwiftUI

@MainActor
final class HUDController {
    static let shared = HUDController()

    private var panel: NSPanel?
    private var host: NSHostingView<RecordingHUD>?
    private var model = HUDModel()
    private let hudSize = NSSize(width: 196, height: 44)

    func show(phase: DictationPhase, level: Float, elapsedSeconds: Int = 0) {
        model.phase = phase
        model.level = level
        model.elapsedSeconds = elapsedSeconds
        model.onTap = { DictationPipeline.shared.cancel() }
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
        model.elapsedSeconds = 0
    }

    private func makePanel() {
        let view = NSHostingView(rootView: RecordingHUD(model: model))
        view.frame = NSRect(origin: .zero, size: hudSize)
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
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        self.panel = panel
    }

    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let size = hudSize
        panel.setContentSize(size)
        let x = screen.visibleFrame.midX - size.width / 2
        let y = screen.visibleFrame.minY + 22
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

@MainActor
final class HUDModel: ObservableObject {
    @Published var phase: DictationPhase = .idle
    @Published var level: Float = 0
    @Published var elapsedSeconds: Int = 0
    var onTap: (() -> Void)?
}

struct RecordingHUD: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        Button {
            model.onTap?()
        } label: {
            HStack(spacing: 8) {
                statusGlyph
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(YaptypeTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(YaptypeTheme.muted)
            }
            .padding(.horizontal, 12)
            .frame(width: 196, height: 44)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var title: String {
        switch model.phase {
        case .recording: "Listening"
        case .preparing: "Preparing"
        case .transcribing: "Transcribing"
        case .rewriting: "Cleaning"
        case .inserting: "Inserting"
        case .error: "Tap to dismiss"
        case .idle: "Ready"
        }
    }

    private var helpText: String {
        switch model.phase {
        case .recording: "Release your hotkey to transcribe. Click or press Esc to cancel."
        case .rewriting: "Cleaning grammar. Click to cancel."
        case .error(let message): message
        default: "Click or press Esc to dismiss."
        }
    }

    private var statusGlyph: some View {
        ZStack {
            Circle()
                .fill(indicatorColor.opacity(0.16))
                .frame(width: 24, height: 24)
            switch model.phase {
            case .recording:
                Circle()
                    .fill(YaptypeTheme.green)
                    .frame(
                        width: 8 + CGFloat(min(model.level, 1)) * 8,
                        height: 8 + CGFloat(min(model.level, 1)) * 8
                    )
                    .animation(.easeOut(duration: 0.08), value: model.level)
            case .rewriting:
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(YaptypeTheme.orange)
            case .transcribing:
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(YaptypeTheme.ink)
            case .preparing:
                Image(systemName: "hourglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(YaptypeTheme.ink)
            case .inserting:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(YaptypeTheme.green)
            case .error:
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
            case .idle:
                Circle()
                    .fill(YaptypeTheme.muted)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 24, height: 24)
    }

    private var indicatorColor: Color {
        switch model.phase {
        case .recording, .inserting: YaptypeTheme.green
        case .rewriting: YaptypeTheme.orange
        case .error: .orange
        default: YaptypeTheme.ink
        }
    }
}
