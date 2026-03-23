//
//  GoogleProvider.swift
//  MixedReality
//

import Foundation

enum GoogleModel: String, Codable, CaseIterable {
    case gemini_2_5_flash = "gemini-2.5-flash"
    case gemini_2_5_pro = "gemini-2.5-pro"
}

private struct GoogleGenerateContentRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }

        let parts: [Part]
    }

    let systemInstruction: Content?
    let contents: [Content]

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
    }
}

private struct GoogleGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]?
        }

        let content: Content?
    }

    let candidates: [Candidate]?
}

private struct GoogleErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let code: Int?
        let message: String?
    }

    let error: APIError
}

final class GoogleProvider: LLMProvider {
    private let model: GoogleModel
    private let apiKey: String?
    private let session: URLSession

    init(artifacts: ArtifactService, experiment: ExperimentModel, model: GoogleModel) {
        _ = artifacts
        _ = experiment
        self.model = model
        self.apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
            ?? ProcessInfo.processInfo.environment["GOOGLE_API_KEY"]
        self.session = Self.makeSession()
    }

    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw LLMProviderError.runtimeError(
                "Missing Gemini API key. Set GEMINI_API_KEY (or GOOGLE_API_KEY)."
            )
        }

        let body = GoogleGenerateContentRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(parts: [.init(text: userPrompt)])]
        )

        var request = URLRequest(
            url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent")!
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(body)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMProviderError.noResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let errorMessage = (try? JSONDecoder().decode(GoogleErrorEnvelope.self, from: data).error.message)
                ?? (String(data: data, encoding: .utf8) ?? "<unreadable>")
            throw LLMProviderError.httpError(code: http.statusCode, body: errorMessage)
        }

        let decoded = try JSONDecoder().decode(GoogleGenerateContentResponse.self, from: data)
        let text = decoded.candidates?
            .compactMap({ $0.content?.parts })
            .flatMap({ $0 })
            .compactMap({ $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty })

        guard let text else {
            throw LLMProviderError.noResponse
        }

        return text
    }

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }
}
