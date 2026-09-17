import Foundation

enum RewriteGuard {
    static func isFaithfulRewrite(original: String, candidate: String) -> Bool {
        let source = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !output.isEmpty else { return false }
        if output.count > max(120, source.count * 3) { return false }

        let sourceWords = words(in: source)
        let outputLower = output.lowercased()
        if assistantPhrases.contains(where: { outputLower.contains($0) && !source.lowercased().contains($0) }) {
            return false
        }

        let content = sourceWords.filter { $0.count > 2 }
        guard content.count >= 2 else { return true }
        let matched = content.filter { outputLower.contains($0) }.count
        return Double(matched) / Double(content.count) >= 0.35
    }

    private static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static let assistantPhrases = [
        "how about you",
        "thank you for asking",
        "i'm doing well",
        "i am doing well",
        "i recommend",
        "i would recommend",
        "happy to help",
        "as an ai",
        "let me know if",
        "that's a great question",
        "of course!",
        "sure thing"
    ]
}
