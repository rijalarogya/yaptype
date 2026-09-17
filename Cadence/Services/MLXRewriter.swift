import Foundation

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

#if canImport(MLXHuggingFace)
import MLXHuggingFace
#endif

#if canImport(HuggingFace)
import HuggingFace
#endif

#if canImport(Tokenizers)
import Tokenizers
#endif

@MainActor
final class MLXRewriter: RewriteEngine {
    let name = "Qwen 1.5B"

    #if canImport(MLXLLM)
    private var container: ModelContainer?
    #endif

    var isReady: Bool {
        #if canImport(MLXLLM)
        container != nil
        #else
        false
        #endif
    }

    var isAvailable: Bool { isReady }

    func load(progress: @escaping @Sendable (Double) -> Void) async throws {
        #if canImport(MLXLLM) && canImport(MLXHuggingFace) && canImport(HuggingFace) && canImport(Tokenizers)
        let configuration = LLMRegistry.qwen2_5_1_5b
        container = try await #huggingFaceLoadModelContainer(
            configuration: configuration,
            progressHandler: { progress($0.fractionCompleted) }
        )
        #else
        throw RewriteUnavailableError.mlxNotLoaded
        #endif
    }

    func rewrite(_ text: String) async throws -> String {
        #if canImport(MLXLLM)
        guard let container else { throw RewriteUnavailableError.mlxNotLoaded }
        let prompt = RewritePrompt.userPrompt(for: text)
        let generated = try await container.perform { context in
            let input = try await context.processor.prepare(input: UserInput(prompt: prompt))
            let result = try generate(
                input: input,
                parameters: GenerateParameters(maxTokens: 400, temperature: 0.2),
                context: context
            )
            return result.output
        }
        return generated.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw RewriteUnavailableError.mlxNotLoaded
        #endif
    }
}
