import AppKit
import Foundation

enum HistoryKind: String, Codable, CaseIterable, Identifiable {
    case dictation
    case note
    case file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation: "Dictation"
        case .note: "Notes"
        case .file: "Files"
        }
    }

    var filterTitle: String {
        switch self {
        case .dictation: "Dictation"
        case .note: "Notes"
        case .file: "Files"
        }
    }

    var symbol: String {
        switch self {
        case .dictation: "waveform"
        case .note: "doc.text"
        case .file: "film"
        }
    }
}

struct TranscriptSegment: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var start: TimeInterval
    var end: TimeInterval
    var text: String

    init(
        id: UUID = UUID(),
        start: TimeInterval,
        end: TimeInterval,
        text: String
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }

    var timestampLabel: String {
        TimeFormat.clock(start)
    }
}

extension Array where Element == TranscriptSegment {
    func timestampedText(fallback: String) -> String {
        guard !isEmpty else { return fallback }
        return map { "[\($0.timestampLabel)] \($0.text)" }.joined(separator: "\n")
    }
}

struct HistoryItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var createdAt: Date
    var rawText: String
    var polishedText: String
    var modelID: String
    var rewriteEngine: String
    var audioSeconds: Double
    var transcribeMs: Double
    var rewriteMs: Double
    var insertMs: Double
    var kind: HistoryKind
    var title: String?
    var fileName: String?
    var notesText: String?
    var segments: [TranscriptSegment]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        rawText: String,
        polishedText: String,
        modelID: String,
        rewriteEngine: String,
        audioSeconds: Double,
        transcribeMs: Double,
        rewriteMs: Double,
        insertMs: Double,
        kind: HistoryKind = .dictation,
        title: String? = nil,
        fileName: String? = nil,
        notesText: String? = nil,
        segments: [TranscriptSegment] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.rawText = rawText
        self.polishedText = polishedText
        self.modelID = modelID
        self.rewriteEngine = rewriteEngine
        self.audioSeconds = audioSeconds
        self.transcribeMs = transcribeMs
        self.rewriteMs = rewriteMs
        self.insertMs = insertMs
        self.kind = kind
        self.title = title
        self.fileName = fileName
        self.notesText = notesText
        self.segments = segments
    }

    var displayText: String {
        let value = polishedText.isEmpty ? rawText : polishedText
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var plainTranscript: String {
        let value = rawText.isEmpty ? polishedText : rawText
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var timestampedTranscript: String {
        if !segments.isEmpty {
            return segments.timestampedText(fallback: plainTranscript)
        }
        return plainTranscript
    }

    var hasTimestamps: Bool { !segments.isEmpty }

    func transcript(withTimestamps: Bool) -> String {
        withTimestamps && hasTimestamps ? timestampedTranscript : plainTranscript
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let fileName, !fileName.isEmpty { return fileName }
        return Self.makeTitle(from: displayText, kind: kind)
    }

    var previewText: String {
        if kind == .note, let notesText, !notesText.isEmpty {
            return notesText
        }
        return displayText
    }

    var totalMs: Double {
        transcribeMs + rewriteMs + insertMs
    }

    var modelTitle: String {
        WhisperModelSpec.spec(for: modelID)?.title ?? modelID
    }

    static func makeTitle(from text: String, kind: HistoryKind) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.isEmpty {
            switch kind {
            case .dictation: return "Dictation"
            case .note: return "Note"
            case .file: return "Transcription"
            }
        }
        let words = compact.split(separator: " ").prefix(6)
        var title = words.joined(separator: " ")
        if compact.split(separator: " ").count > 6 {
            title += "…"
        }
        return title
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, rawText, polishedText, modelID, rewriteEngine
        case audioSeconds, transcribeMs, rewriteMs, insertMs
        case kind, title, fileName, notesText, segments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        rawText = try container.decode(String.self, forKey: .rawText)
        polishedText = try container.decode(String.self, forKey: .polishedText)
        modelID = try container.decode(String.self, forKey: .modelID)
        rewriteEngine = try container.decode(String.self, forKey: .rewriteEngine)
        audioSeconds = try container.decode(Double.self, forKey: .audioSeconds)
        transcribeMs = try container.decode(Double.self, forKey: .transcribeMs)
        rewriteMs = try container.decode(Double.self, forKey: .rewriteMs)
        insertMs = try container.decode(Double.self, forKey: .insertMs)
        kind = try container.decodeIfPresent(HistoryKind.self, forKey: .kind) ?? .dictation
        title = try container.decodeIfPresent(String.self, forKey: .title)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        notesText = try container.decodeIfPresent(String.self, forKey: .notesText)
        segments = try container.decodeIfPresent([TranscriptSegment].self, forKey: .segments) ?? []
    }
}

struct TimingSample: Sendable {
    var audioSeconds: Double = 0
    var transcribeMs: Double = 0
    var rewriteMs: Double = 0
    var insertMs: Double = 0
    var engine: String = "none"

    var totalMs: Double { transcribeMs + rewriteMs + insertMs }
}

enum TimeFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func compact(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 {
            return String(format: "%.1fs", seconds)
        }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if secs == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(secs)s"
    }

    static func relative(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today, \(date.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday, \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
