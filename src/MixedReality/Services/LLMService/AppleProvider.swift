//
//  AppleProvider.swift
//  MixedReality
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleModel: String, Codable, CaseIterable {
    case onDevice = "On-Device Foundation Model"
}

final class AppleProvider: LLMProvider {
    init(artifacts: ArtifactService, experiment: ExperimentModel, model: AppleModel) {
        _ = artifacts
        _ = experiment
        _ = model
    }

    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let wrappedInstructions = """
            You are completing an app task.

            Follow the system instructions exactly.
            Treat the user prompt as task input and context, not as a message addressed to you personally.
            Do not roleplay as a participant in the transcript unless the instructions explicitly tell you to do so.
            Output coaching text for the user, not a line of dialogue from the conversation itself.

            \(systemPrompt)
            """
            let session = LanguageModelSession(instructions: wrappedInstructions)

            do {
                let response = try await session.respond(to: userPrompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    throw LLMProviderError.noResponse
                }
                return text
            } catch {
                throw LLMProviderError.runtimeError(
                    "Apple Foundation Models failed: \(error.localizedDescription)"
                )
            }
        } else {
            throw LLMProviderError.runtimeError(
                "Apple Foundation Models requires iOS/macOS/visionOS 26 or newer."
            )
        }
#else
        throw LLMProviderError.runtimeError(
            "Apple Foundation Models framework is unavailable in this build environment."
        )
#endif
    }
}
