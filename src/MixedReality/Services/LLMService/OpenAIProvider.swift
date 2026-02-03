//
//  OpenAIProvider.swift
//  MixedReality
//

import Foundation

enum OpenAIModel: String, Encodable, CaseIterable {
    case gpt_4_1 = "gpt-4.1"
    case gpt_4_1_mini = "gpt-4.1-mini"
    case gpt_5_2 = "gpt-5.2-chat-latest"
    case gpt_5_mini = "gpt-5-mini"
    /// GPT-5 nano is extremely slow for some reason (do not use)
    case gpt_5_nano = "gpt-5-nano"
}

struct OpenAIChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}

final class OpenAIProvider : LLMProvider {
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let model: OpenAIModel
    
    private let apiKey: String
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, model: OpenAIModel) {
        self.artifacts = artifacts
        self.experiment = experiment
        self.model = model
        
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            fatalError("Missing OPENAI_API_KEY in environment")
        }
        self.apiKey = key
    }
    
    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": self.model.rawValue,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMProviderError.noResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw LLMProviderError.httpError(code: http.statusCode, body: bodyText)
        }

        let decoded = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        return decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
