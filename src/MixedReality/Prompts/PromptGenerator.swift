import Foundation
import OSLog

final class PromptGenerator {
    private let logger = Logger(subsystem: "NLP", category: "SpeechProcessor")

    private let promptType: String
    private let supportLevel: Int
    private let apiKey: String
    private var appModel: AppModel

    // ----------------------------------------
    // MARK: Prompt Dictionaries
    // ----------------------------------------

    private static let basePrompt = """
    You are a conversational support assistant for a mixed-reality environment (Apple Vision Pro) that helps older adults sustain meaningful conversation.
    You monitor dialogue and generate subtle, context-aware cues when a pause or hesitation is detected.
    Keep every response natural, empathetic, and contextually grounded.
    Avoid pronouns without context. Reference concrete topics.
    The goal is to help the user continue speaking — not to take over the conversation.
    """

    private static let supportLevels: [Int: String] = [
        1: """
        Provide very short, minimal suggestions (1 line max). Do not summarize or reframe.
        Focus only on the last spoken detail.
        """,
        2: """
        Provide a concise suggestion (1–2 sentences) with light context from the last 1–2 utterances.
        Gently reference what the user or partner last said.
        """,
        3: """
        Provide a warm, context-rich prompt (2–3 sentences).
        Briefly summarize multiple relevant details from recent turns before cueing the next thought.
        Reflect emotional tone, show gentle curiosity, and invite elaboration naturally.
        """
    ]

    private static let promptTypes: [String: String] = [
        "semantic_completion": """
        When Triggered: A pause mid-sentence or search for a word.
        Goal: Offer a gentle, natural completion cue that helps continue the user’s train of thought and remind the conversation so far.
        """,
        "turn_taking": """
        When Triggered: No response to another speaker’s question or statement.
        Goal: Gently cue a response to maintain conversational flow and reciprocity.
        """,
        "reminiscence": """
        When Triggered: The speaker loses track of a story or earlier reference.
        Goal: Help reconnect to the prior context or person mentioned.
        """,
        "affective_validation": """
        When Triggered: A pause after sharing something emotional.
        Goal: Encourage gentle reflection or elaboration.
        """,
        "conversational_bridging": """
        When Triggered: Hesitation when transitioning between topics.
        Goal: Smoothly bridge to a related idea or follow-up.
        """
    ]

    // ----------------------------------------
    // MARK: Init
    // ----------------------------------------

    init(appModel: AppModel, promptType: String = "semantic_completion", supportLevel: Int = 2) {
        self.appModel = appModel
        self.promptType = promptType
        self.supportLevel = supportLevel

        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            fatalError("Missing OPENAI_API_KEY in environment")
        }
        self.apiKey = key
    }

    // ----------------------------------------
    // MARK: Public API
    // ----------------------------------------

    public func generate(evt: InterventionEvent) async {
        logger.info("Generating prompt from \(evt.context.count) transcript chunks")

        let recentUtterances = assembleRecentUtterances(chunks: evt.context)
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(recentUtterances: recentUtterances)

        do {
            let output = try await callOpenAI(systemPrompt: systemPrompt, userPrompt: userPrompt)
            self.appModel.prompt = output
            logger.info("💡 Generated prompt \(evt.id): \(output)")
        } catch {
            logger.error("OpenAI call failed: \(error.localizedDescription)")
            self.appModel.prompt = ""
        }
    }

    // ----------------------------------------
    // MARK: OpenAI HTTP Call
    // ----------------------------------------

    private func callOpenAI(systemPrompt: String, userPrompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ],
            "max_tokens": 60
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "NoHTTPResponse", code: -1)
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw NSError(domain: "OpenAIError", code: http.statusCode, userInfo: [
                "body": bodyText
            ])
        }

        // Decode minimal subset of API response
        struct ChatCompletionResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // ----------------------------------------
    // MARK: Prompt Assembly
    // ----------------------------------------

    private func assembleRecentUtterances(chunks: [TranscriptChunk]) -> String {
        let primary = appModel.primarySpeakerID

        let filtered = chunks
            .filter { $0.isFinal && !$0.isEmptyText }
            .map { "[\($0.speakerID)] \($0.text.trimmingCharacters(in: .whitespacesAndNewlines))" }

        if filtered.isEmpty { return "" }
        return filtered.joined(separator: "\n")
    }

    private func buildSystemPrompt() -> String {
        let base = Self.basePrompt
        let support = Self.supportLevels[supportLevel] ?? ""
        let type = Self.promptTypes[promptType] ?? ""

        return """
        \(base)
        
        ### Supported User
        [\(self.appModel.primarySpeakerID)]

        ### Support Level
        \(support)

        ### Prompt Type
        \(type)

        ### Output Rules
        - Avoid meta-language.
        - Use nouns (not pronouns) to anchor topic context.
        - Sound like a human conversational partner offering subtle help.
        - Remember that the user is having a conversation with someone else, not you.
        """
    }

    private func buildUserPrompt(recentUtterances: String) -> String {
        """
        The following transcript represents the recent portion of a live conversation.
        A conversational pause has been detected.

        Conversation Context:
        \(recentUtterances)

        Please output only one short conversational cue suitable for \(self.appModel.primarySpeakerID) to say next.
        """
    }
}
