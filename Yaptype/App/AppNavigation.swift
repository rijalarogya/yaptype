import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum AppPage: String, Hashable, CaseIterable, Identifiable {
    case home
    case noteTaker
    case fileTranscription
    case history
    case general
    case models
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .noteTaker: "Note Taker"
        case .fileTranscription: "File Transcription"
        case .history: "History"
        case .general: "General"
        case .models: "Models"
        case .diagnostics: "Diagnostics"
        }
    }

    var subtitle: String {
        switch self {
        case .home: "Everything you need to turn speech into text."
        case .noteTaker: "Record conversations, meetings, or ideas and keep the transcript in one place."
        case .fileTranscription: "Turn audio and video files into text."
        case .history: "Everything you’ve dictated and transcribed."
        case .general: "Configure dictation, rewriting, permissions, and startup behavior."
        case .models: "Choose and manage the speech and rewrite models used by Yaptype."
        case .diagnostics: "Check performance, runtime status, and system readiness."
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .noteTaker: "doc.text"
        case .fileTranscription: "waveform"
        case .history: "clock"
        case .general: "gearshape"
        case .models: "square.stack.3d.up"
        case .diagnostics: "bolt"
        }
    }

    var isSettings: Bool {
        switch self {
        case .general, .models, .diagnostics: true
        default: false
        }
    }
}

@MainActor
final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()

    @Published var page: AppPage = .home
    @Published var pendingFileURL: URL?
    @Published var pendingFilePicker = false

    func go(_ page: AppPage) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.page = page
        }
    }

    func startNote() {
        go(.noteTaker)
    }

    func chooseFile() {
        pendingFilePicker = true
        go(.fileTranscription)
    }

    func consumeFilePicker() -> Bool {
        guard pendingFilePicker else { return false }
        pendingFilePicker = false
        return true
    }

    func openFile(_ url: URL) {
        pendingFileURL = url
        page = .fileTranscription
    }
}
