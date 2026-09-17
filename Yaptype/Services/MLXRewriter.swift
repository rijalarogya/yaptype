import Foundation
import Hub

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

@MainActor
final class MLXRewriter: RewriteEngine {
    let name = "Qwen 1.5B"

    private var downloaded = false
    #if canImport(MLXLLM)
    private var container: ModelContainer?
    #endif

    var isReady: Bool {
        #if canImport(MLXLLM)
        container != nil
        #else
        downloaded || ModelManager.shared.isMLXInstalled(.recommended)
        #endif
    }

    var isAvailable: Bool { isReady }

    var canRunModel: Bool {
        #if canImport(MLXLLM)
        container != nil
        #else
        false
        #endif
    }

    func load(progress: @escaping @Sendable (Double) -> Void) async throws {
        let spec = MLXModelSpec.recommended
        let hub = HubApi(downloadBase: ModelManager.shared.mlxDownloadBase)
        _ = try await hub.snapshot(from: spec.huggingFaceID) { snapshot in
            progress(snapshot.fractionCompleted)
        }
        downloaded = true

        #if canImport(MLXLLM)
        let configuration = ModelConfiguration(
            id: spec.huggingFaceID,
            extraEOSTokens: ["<|im_end|>"]
        )
        container = try await LLMModelFactory.shared.loadContainer(
            hub: hub,
            configuration: configuration
        ) { snapshot in
            progress(snapshot.fractionCompleted)
        }
        #endif
    }

    func rewrite(_ text: String) async throws -> String {
        #if canImport(MLXLLM)
        guard let container else { throw RewriteUnavailableError.mlxNotLoaded }
        let messages = [
            ["role": "system", "content": RewritePrompt.system],
            ["role": "user", "content": text]
        ]
        let generated = try await container.perform { context in
            let input = try await context.processor.prepare(input: UserInput(messages: messages))
            let result = generate(
                input: input,
                parameters: GenerateParameters(temperature: 0.2),
                context: context
            ) { tokens in
                tokens.count >= 400 ? .stop : .more
            }
            return result.output
        }
        return generated.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw RewriteUnavailableError.mlxRuntimeUnavailable
        #endif
    }
}
