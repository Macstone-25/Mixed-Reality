//
//  OpenAIProvider.swift
//  MixedReality
//

import Foundation

enum OpenAIModel: String, Codable, CaseIterable {
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
    private var session: URLSession
    private static let maxRetryAttempts = 3
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, model: OpenAIModel) {
        self.artifacts = artifacts
        self.experiment = experiment
        self.model = model
        
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            fatalError("Missing OPENAI_API_KEY in environment")
        }
        self.apiKey = key
        self.session = Self.makeSession()
    }
    
    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        var lastError: Error?

        for attempt in 1 ... Self.maxRetryAttempts {
            do {
                return try await generateOnce(systemPrompt: systemPrompt, userPrompt: userPrompt)
            } catch let cancellation as CancellationError {
                throw cancellation
            } catch {
                lastError = error

                let shouldRetry = attempt < Self.maxRetryAttempts && Self.isTransient(error: error)
                guard shouldRetry else { throw error }

                if Self.shouldRefreshSession(for: error) {
                    refreshSession()
                }

                let delaySeconds = Self.retryDelaySeconds(forAttempt: attempt)
                let formattedDelay = String(format: "%.1f", delaySeconds)
                await artifacts.logEvent(
                    type: "LLM",
                    message: "Transient OpenAI failure (attempt \(attempt)/\(Self.maxRetryAttempts)): \(error.localizedDescription). Retrying in \(formattedDelay)s."
                )

                let nanos = UInt64(delaySeconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanos)
            }
        }

        throw lastError ?? LLMProviderError.noResponse
    }

    private func generateOnce(systemPrompt: String, userPrompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": self.model.rawValue,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMProviderError.noResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw LLMProviderError.httpError(code: http.statusCode, body: bodyText)
        }

        let decoded = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        return decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

    private func refreshSession() {
        session.invalidateAndCancel()
        session = Self.makeSession()
    }

    private static func retryDelaySeconds(forAttempt attempt: Int) -> Double {
        let base = 0.5 * pow(2.0, Double(max(attempt - 1, 0)))
        let jitter = Double.random(in: 0 ... 0.25)
        return min(base + jitter, 3.0)
    }

    private static func isTransient(error: Error) -> Bool {
        if let providerError = error as? LLMProviderError {
            switch providerError {
            case .noResponse:
                return true
            case .httpError(let code, _):
                if code == 408 || code == 409 || code == 425 || code == 429 {
                    return true
                }
                return (500 ... 599).contains(code)
            case .runtimeError:
                return false
            }
        }

        if let urlError = error as? URLError {
            return isTransient(urlErrorCode: urlError.code)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return isTransient(urlErrorCode: URLError.Code(rawValue: nsError.code))
        }

        return false
    }

    private static func isTransient(urlErrorCode: URLError.Code) -> Bool {
        switch urlErrorCode {
        case .networkConnectionLost,
             .notConnectedToInternet,
             .timedOut,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .resourceUnavailable,
             .cannotLoadFromNetwork,
             .dataNotAllowed,
             .internationalRoamingOff,
             .callIsActive:
            return true
        default:
            return false
        }
    }

    private static func shouldRefreshSession(for error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .networkConnectionLost || urlError.code == .timedOut
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            return code == .networkConnectionLost || code == .timedOut
        }

        return false
    }
}
