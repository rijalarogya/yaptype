import Foundation

struct WhisperModelSpec: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let approxBytes: Int64
    let recommended: Bool
    let englishOnly: Bool

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: approxBytes, countStyle: .file)
    }

    static let recommendedID = "large-v3-v20240930_turbo"

    static let recommended: WhisperModelSpec =
        all.first { $0.id == recommendedID } ?? all[0]

    static var multilingual: [WhisperModelSpec] { all.filter { !$0.englishOnly } }
    static var englishOnlyModels: [WhisperModelSpec] { all.filter(\.englishOnly) }

    static let all: [WhisperModelSpec] = [
        WhisperModelSpec(
            id: "large-v3-v20240930_turbo",
            title: "Large v3 Turbo",
            subtitle: "Best daily driver. Hears any language.",
            approxBytes: 1_600_000_000,
            recommended: true,
            englishOnly: false
        ),
        WhisperModelSpec(
            id: "large-v3-v20240930_626MB",
            title: "Turbo compressed",
            subtitle: "Smaller download, same languages.",
            approxBytes: 626_000_000,
            recommended: false,
            englishOnly: false
        ),
        WhisperModelSpec(
            id: "small",
            title: "Small",
            subtitle: "Lighter multilingual model.",
            approxBytes: 466_000_000,
            recommended: false,
            englishOnly: false
        ),
        WhisperModelSpec(
            id: "base",
            title: "Base",
            subtitle: "Fast and small. Weaker accuracy.",
            approxBytes: 145_000_000,
            recommended: false,
            englishOnly: false
        ),
        WhisperModelSpec(
            id: "tiny",
            title: "Tiny",
            subtitle: "Smallest multilingual model.",
            approxBytes: 75_000_000,
            recommended: false,
            englishOnly: false
        ),
        WhisperModelSpec(
            id: "small.en",
            title: "Small English",
            subtitle: "English only.",
            approxBytes: 466_000_000,
            recommended: false,
            englishOnly: true
        ),
        WhisperModelSpec(
            id: "base.en",
            title: "Base English",
            subtitle: "English only.",
            approxBytes: 145_000_000,
            recommended: false,
            englishOnly: true
        ),
        WhisperModelSpec(
            id: "tiny.en",
            title: "Tiny English",
            subtitle: "English only.",
            approxBytes: 75_000_000,
            recommended: false,
            englishOnly: true
        )
    ]

    static func spec(for id: String) -> WhisperModelSpec? {
        all.first { $0.id == id }
    }

    func supports(_ language: TranscriptionLanguage) -> Bool {
        if language.needsMultilingualModel { return !englishOnly }
        return true
    }

    static func preferredMultilingual(installed: Set<String>) -> WhisperModelSpec? {
        let order = [
            recommendedID,
            "large-v3-v20240930_626MB",
            "small",
            "base",
            "tiny"
        ]
        return order.compactMap(spec(for:)).first { installed.contains($0.id) }
    }
}

struct MLXModelSpec: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let huggingFaceID: String
    let approxBytes: Int64

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: approxBytes, countStyle: .file)
    }

    static let recommended = MLXModelSpec(
        id: "qwen2.5-1.5b",
        title: "Qwen2.5 1.5B Instruct (4-bit)",
        subtitle: "Local rewrite when Apple Intelligence is unavailable.",
        huggingFaceID: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        approxBytes: 1_000_000_000
    )

    static let all = [recommended]
}
