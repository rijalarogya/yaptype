import Foundation

enum NotesExtractor {
    static func extract(_ transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return """
            Key points
            - None yet

            Action items
            - None yet
            """
        }

        let sentences = splitSentences(trimmed)
        let actionHints = ["should", "need to", "needs to", "let's", "lets", "will", "todo", "to-do", "action", "follow up", "follow-up", "assign", "finish", "finalize", "schedule"]
        let actions = sentences.filter { sentence in
            let lower = sentence.lowercased()
            return actionHints.contains { lower.contains($0) }
        }
        let points = sentences.filter { !actions.contains($0) }.prefix(5)

        let pointLines = points.isEmpty
            ? ["- None yet"]
            : points.map { "- \($0)" }
        let actionLines = actions.isEmpty
            ? ["- None yet"]
            : actions.prefix(6).map { "- \($0)" }

        return """
        Key points
        \(pointLines.joined(separator: "\n"))

        Action items
        \(actionLines.joined(separator: "\n"))
        """
    }

    private static func splitSentences(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ".!?\n")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 8 }
    }
}
