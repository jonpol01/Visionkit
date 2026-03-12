//
//  VLMService.swift
//  Visionkit
//
//  FastVLM inference service — minimal wrapper for text recognition.
//

import CoreImage
import Foundation
import MLX
import MLXLMCommon
import MLXRandom
import MLXVLM

@Observable
@MainActor
class VLMService {

    // MARK: - Public state

    public var output = ""
    public var isLoaded = false
    public var running = false
    public var statusMessage = ""

    // MARK: - Config

    private let generateParameters = GenerateParameters(temperature: 0.0)
    private let maxTokens = 120

    // MARK: - Internal

    private enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    private var loadState = LoadState.idle
    private var currentTask: Task<Void, Never>?

    // MARK: - Init

    public init() {
        FastVLM.register(modelFactory: VLMModelFactory.shared)
    }

    // MARK: - Load

    public func load() async {
        do {
            _ = try await _load()
        } catch {
            statusMessage = "VLM load error: \(error.localizedDescription)"
        }
    }

    private func _load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            statusMessage = "Loading FastVLM…"
            let config = FastVLM.modelConfiguration

            let container = try await VLMModelFactory.shared.loadContainer(
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

    // MARK: - Recognize

    /// Run FastVLM on a pixel buffer and return the recognized text.
    /// `prompt` controls what you ask the model, e.g. "Read the text in this image."
    public func recognize(
        pixelBuffer: CVPixelBuffer,
        prompt: String = "Read all the text in this image. Output only the text, nothing else."
    ) async -> String {
        guard !running else { return output }

        running = true
        defer { running = false }

        do {
            let container = try await _load()

            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let userInput = UserInput(
                prompt: .text(prompt),
                images: [.ciImage(CIImage(cvPixelBuffer: pixelBuffer))]
            )

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
            let msg = "VLM error: \(error.localizedDescription)"
            self.output = msg
            return msg
        }
    }

    // MARK: - Cancel

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        running = false
        output = ""
    }
}
