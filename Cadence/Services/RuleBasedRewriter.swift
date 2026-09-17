import Foundation

enum RuleBasedRewriter {
    static func rewrite(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return value }

        let fillers = [
            #"\buh-huh\b"#,
            #"\bum+\b"#,
            #"\buh+\b"#,
            #"\ber+\b"#,
            #"\bah+\b"#,
            #"\bhmm+\b"#,
            #"\bmm+\b"#,
            #"\byou know\b"#,
            #"\bi mean\b"#,
            #"\bkind of\b"#,
            #"\bsort of\b"#,
            #"\bbasically\b"#,
            #"\bliterally\b"#
        ]
        for pattern in fillers {
            value = value.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        value = applySelfCorrections(value)

        let spoken: [(String, String)] = [
            (#"\bnew paragraph\b"#, "\n\n"),
            (#"\bnew line\b"#, "\n"),
            (#"\bquestion mark\b"#, "?"),
            (#"\bexclamation point\b"#, "!"),
            (#"\bexclamation mark\b"#, "!"),
            (#"\bcomma\b"#, ","),
            (#"\bperiod\b"#, "."),
            (#"\bcolon\b"#, ":"),
            (#"\bsemicolon\b"#, ";")
        ]
        for (pattern, replacement) in spoken {
            value = value.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        value = value.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\s+([,.;:!?])"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = value.first, first.isLetter {
            value = first.uppercased() + value.dropFirst()
        }

        if let last = value.last, last.isLetter || last.isNumber {
            value += "."
        }

        return value
    }

    private static func applySelfCorrections(_ text: String) -> String {
        var value = text
        let patterns = [
            #"\b[\w''-]+(?:,)?\s+(?:no|wait|sorry|scratch that)(?:,)?\s+"#,
            #"\b(?:no wait|scratch that|forget that)\s+"#
        ]
        for pattern in patterns {
            value = value.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return value
    }
}
