import Foundation

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

    var displayText: String {
        polishedText.isEmpty ? rawText : polishedText
    }

    var totalMs: Double {
        transcribeMs + rewriteMs + insertMs
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
