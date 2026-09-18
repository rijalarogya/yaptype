import Foundation

enum RewriteGuard {
    enum ScriptClass: Equatable {
        case latin
        case cjk
        case arabic
        case devanagari
        case other
    }

    static func isFaithfulRewrite(original: String, candidate: String) -> Bool {
        let source = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !output.isEmpty else { return false }

        let limit = max(source.count + 12, Int((Double(source.count) * 1.2).rounded()))
        if output.count > limit { return false }

        let sourceScript = dominantScript(source)
        let outputScript = dominantScript(output)
        if isNonLatin(sourceScript), outputScript == .latin {
            return false
        }

        let sourceWords = words(in: source)
        let outputWords = words(in: output)
        let outputLower = output.lowercased()
        if assistantPhrases.contains(where: { outputLower.contains($0) && !source.lowercased().contains($0) }) {
            return false
        }

        let sourceContent = Set(sourceWords.filter { $0.count > 2 })
        let outputContent = outputWords.filter { $0.count > 2 }
        let newContent = outputContent.filter { word in
            !sourceContent.contains(word) && !functionWords.contains(word)
        }
        if Set(newContent).count >= 3 { return false }

        let content = sourceWords.filter { $0.count > 2 }
        guard content.count >= 2 else { return true }
        let matched = content.filter { outputLower.contains($0) }.count
        return Double(matched) / Double(content.count) >= 0.75
    }

    static func isPrimarilyLatin(_ text: String) -> Bool {
        let script = dominantScript(text)
        return script == .latin || script == .other
    }

    static func dominantScript(_ text: String) -> ScriptClass {
        var cjk = 0
        var arabic = 0
        var devanagari = 0
        var latin = 0

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x3040...0x30FF, 0xAC00...0xD7AF:
                cjk += 1
            case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF:
                arabic += 1
            case 0x0900...0x097F:
                devanagari += 1
            case 0x0041...0x007A, 0x00C0...0x024F:
                latin += 1
            default:
                break
            }
        }

        let ranked: [(ScriptClass, Int)] = [
            (.cjk, cjk),
            (.arabic, arabic),
            (.devanagari, devanagari),
            (.latin, latin)
        ]
        let best = ranked.max(by: { $0.1 < $1.1 })
        guard let best, best.1 > 0 else { return .other }
        return best.0
    }

    private static func isNonLatin(_ script: ScriptClass) -> Bool {
        script == .cjk || script == .arabic || script == .devanagari
    }

    private static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static let functionWords: Set<String> = [
        "did", "does", "was", "were", "had", "has", "have", "been",
        "the", "and", "but", "for", "you", "your"
    ]

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
