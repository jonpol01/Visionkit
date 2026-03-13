//
//  LLMService.swift
//  Visionkit
//
//  Text-only LLM service using Qwen for OCR text correction.
//  Downloads model from HuggingFace on first use.
//

import Foundation
import MLX
import MLXLMCommon
import MLXLLM
import MLXRandom

@Observable
@MainActor
class LLMService {

    // MARK: - Public state

    public var output = ""
    public var isLoaded = false
    public var running = false
    public var statusMessage = ""

    /// Quick gate for callers on the camera thread.
    public var isReady: Bool { isLoaded && !running }

    // MARK: - Config

    private let generateParameters = GenerateParameters(temperature: 0.0)
    private let maxTokens = 40

    /// HuggingFace model ID — change this to try different models.
    /// Qwen3-4B-4bit (~2.5 GB) — stronger correction, still fits iPad 12 GB.
    static let modelID = "mlx-community/Qwen3-4B-4bit"

    // MARK: - Internal

    private enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    private var loadState = LoadState.idle

    // MARK: - Load

    public func load() async {
        do {
            _ = try await _load()
        } catch {
            statusMessage = "LLM load error: \(error.localizedDescription)"
        }
    }

    private func _load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            statusMessage = "Downloading \(Self.modelID)…"

            let config = ModelConfiguration(id: Self.modelID)

            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.statusMessage =
                        "Loading: \(Int(progress.fractionCompleted * 100))%"
                }
            }

            statusMessage = "Ready"
            isLoaded = true
            loadState = .loaded(container)
            return container

        case .loaded(let container):
            return container
        }
    }

    // MARK: - Recognize text (no image)

    /// Ask the LLM to correct/arrange OCR text fragments.
    public func recognizeText(prompt: String) async -> String {
        guard !running else { return output }

        running = true
        defer { running = false }

        do {
            let container = try await _load()

            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let userInput = UserInput(prompt: .text(prompt))

            let result = try await container.perform { context in
                let input = try await context.processor.prepare(input: userInput)

                let result = try MLXLMCommon.generate(
                    input: input,
                    parameters: self.generateParameters,
                    context: context
                ) { tokens in
                    if tokens.count >= self.maxTokens {
                        return .stop
                    }
                    return .more
                }

                return result
            }

            self.output = result.output
            return result.output

        } catch {
            let msg = "LLM error: \(error.localizedDescription)"
            self.output = msg
            return msg
        }
    }
}
