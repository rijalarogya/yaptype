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
        all.first { $0.id == recommendedID } ?? all[2]

    static let all: [WhisperModelSpec] = [
        WhisperModelSpec(
            id: "tiny.en",
            title: "Tiny English",
            subtitle: "Fastest. Good for testing, weaker accuracy.",
            approxBytes: 75_000_000,
            recommended: false,
            englishOnly: true
        ),
        WhisperModelSpec(
            id: "base.en",
            title: "Base English",
            subtitle: "Light and quick for short dictation.",
            approxBytes: 145_000_000,
            recommended: false,
            englishOnly: true
        ),
        WhisperModelSpec(
            id: "small.en",
            title: "Small English",
            subtitle: "Solid laptop default on older M-series chips.",
            approxBytes: 466_000_000,
            recommended: false,
            englishOnly: true
        ),
        WhisperModelSpec(
            id: "large-v3-v20240930_turbo",
            title: "Large v3 Turbo",
            subtitle: "Best daily driver on Mac. Fast and accurate.",
            approxBytes: 1_600_000_000,
            recommended: true,
            englishOnly: false
        ),
        WhisperModelSpec(
            id: "large-v3-v20240930_626MB",
            title: "Large v3 Turbo (compressed)",
            subtitle: "Near-turbo quality at a smaller download.",
            approxBytes: 626_000_000,
            recommended: false,
            englishOnly: false
        ),
        WhisperModelSpec(
            id: "small",
            title: "Small multilingual",
            subtitle: "Smaller multilingual model when you switch languages.",
            approxBytes: 466_000_000,
            recommended: false,
            englishOnly: false
        )
    ]

    static func spec(for id: String) -> WhisperModelSpec? {
        all.first { $0.id == id }
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
