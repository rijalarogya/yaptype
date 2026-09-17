import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
protocol RewriteEngine: AnyObject {
    var name: String { get }
    var isAvailable: Bool { get }
    func rewrite(_ text: String) async throws -> String
}

@MainActor
final class RewriteService: ObservableObject {
    static let shared = RewriteService()

    @Published private(set) var lastEngineName = "Rules"
    @Published private(set) var appleIntelligenceAvailable = false
    @Published private(set) var mlxReady = false
    @Published private(set) var mlxCanRun = false
    @Published private(set) var mlxLoading = false
    @Published private(set) var mlxProgress: Double = 0
    @Published var lastError: String?

    private let apple = AppleFoundationRewriter()
    private let mlx = MLXRewriter()
    private let settings = AppSettings.shared

    func refreshAvailability() {
        appleIntelligenceAvailable = apple.isAvailable
        mlxReady = mlx.isReady
        mlxCanRun = mlx.canRunModel
    }

    func rewrite(_ text: String) async -> (text: String, engine: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.rewriteEnabled, !trimmed.isEmpty else {
            lastEngineName = "Off"
            return (trimmed, "Off")
        }

        if settings.preferAppleIntelligence, apple.isAvailable {
            do {
                let result = try await apple.rewrite(trimmed)
                if RewriteGuard.isFaithfulRewrite(original: trimmed, candidate: result) {
                    lastEngineName = apple.name
                    return (result, apple.name)
                }
            } catch {
                lastError = error.localizedDescription
            }
        }

        if mlx.canRunModel {
            do {
                let result = try await mlx.rewrite(trimmed)
                if RewriteGuard.isFaithfulRewrite(original: trimmed, candidate: result) {
                    lastEngineName = mlx.name
                    return (result, mlx.name)
                }
            } catch {
                lastError = error.localizedDescription
            }
        }

        let fallback = RuleBasedRewriter.rewrite(trimmed)
        lastEngineName = "Rules"
        return (fallback, "Rules")
    }

    func prepareMLX() async {
        mlxLoading = true
        mlxProgress = 0
        lastError = nil
        defer { mlxLoading = false }
        do {
            try await mlx.load { [weak self] progress in
                Task { @MainActor in
                    self?.mlxProgress = progress
                }
            }
            mlxReady = mlx.isReady
            mlxCanRun = mlx.canRunModel
            if mlx.isReady, !mlx.canRunModel {
                lastError = nil
            }
        } catch {
            lastError = "Could not download the local rewrite model: \(error.localizedDescription)"
            mlxReady = false
        }
    }
}

@MainActor
final class AppleFoundationRewriter: RewriteEngine {
    let name = "Apple Intelligence"

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    func rewrite(_ text: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session = LanguageModelSession(instructions: RewritePrompt.system)
            let wordCount = max(1, text.split(whereSeparator: \.isWhitespace).count)
            let options = GenerationOptions(
                temperature: 0,
                maximumResponseTokens: max(48, min(256, wordCount * 4 + 24))
            )
            let response = try await session.respond(
                to: RewritePrompt.userPrompt(for: text),
                options: options
            )
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw RewriteUnavailableError.appleIntelligence
    }
}

enum RewriteUnavailableError: LocalizedError {
    case appleIntelligence
    case mlxNotLoaded
    case mlxRuntimeUnavailable

    var errorDescription: String? {
        switch self {
        case .appleIntelligence:
            "Apple Intelligence is not available on this Mac."
        case .mlxNotLoaded:
            "The local rewrite model is not downloaded yet."
        case .mlxRuntimeUnavailable:
            "Qwen files are on disk. This build cannot run them until Xcode’s Metal toolchain is installed; polish still uses Apple Intelligence or local rules."
        }
    }
}
