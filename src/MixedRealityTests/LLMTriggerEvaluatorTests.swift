import XCTest
@testable import MRCS

final class LLMTriggerEvaluatorTests: XCTestCase {
    func testEvaluate_WhenDecisionTriggers_ReturnsLLMReason() async {
        let llm = MockLLMGenerator(response: #"{"should_trigger":true,"rationale":"The speaker appears stuck after a direct question."}"#)
        let evaluator = LLMTriggerEvaluator(miniLLM: llm)
        
        let chunk = makeChunk(text: "I think the answer is...", isFinal: true)
        let reason = await evaluator.evaluate(chunk: chunk, context: [chunk])
        
        guard case .llmSuggested(let rationale)? = reason else {
            return XCTFail("Expected llmSuggested reason")
        }
        
        XCTAssertEqual(rationale, "The speaker appears stuck after a direct question.")
        XCTAssertEqual(llm.callCount, 1)
    }
    
    func testEvaluate_WhenDecisionDoesNotTrigger_ReturnsNil() async {
        let llm = MockLLMGenerator(response: #"{"should_trigger":false,"rationale":"Conversation is progressing."}"#)
        let evaluator = LLMTriggerEvaluator(miniLLM: llm)
        
        let chunk = makeChunk(text: "We went to the market yesterday.", isFinal: true)
        let reason = await evaluator.evaluate(chunk: chunk, context: [chunk])
        
        XCTAssertNil(reason)
        XCTAssertEqual(llm.callCount, 1)
    }
    
    func testEvaluate_WhenResponseIsInvalidJSON_ReturnsNil() async {
        let llm = MockLLMGenerator(response: "trigger=true because long pause")
        let evaluator = LLMTriggerEvaluator(miniLLM: llm)
        
        let chunk = makeChunk(text: "Well, uh...", isFinal: true)
        let reason = await evaluator.evaluate(chunk: chunk, context: [chunk])
        
        XCTAssertNil(reason)
        XCTAssertEqual(llm.callCount, 1)
    }
    
    func testEvaluate_WhenJSONIsWrappedInCodeFence_ParsesSuccessfully() async {
        let llm = MockLLMGenerator(response: """
            ```json
            {"should_trigger": true, "rationale": "Repeated hesitation near the end of the turn."}
            ```
            """)
        let evaluator = LLMTriggerEvaluator(miniLLM: llm)
        
        let chunk = makeChunk(text: "Um... maybe...", isFinal: true)
        let reason = await evaluator.evaluate(chunk: chunk, context: [chunk])
        
        guard case .llmSuggested(let rationale)? = reason else {
            return XCTFail("Expected llmSuggested reason")
        }
        
        XCTAssertEqual(rationale, "Repeated hesitation near the end of the turn.")
        XCTAssertEqual(llm.callCount, 1)
    }
    
    func testEvaluate_WhenChunkIsInterim_DoesNotCallLLM() async {
        let llm = MockLLMGenerator(response: #"{"should_trigger":true,"rationale":"Should not be used."}"#)
        let evaluator = LLMTriggerEvaluator(miniLLM: llm)
        
        let chunk = makeChunk(text: "Partial transcript...", isFinal: false)
        let reason = await evaluator.evaluate(chunk: chunk, context: [chunk])
        
        XCTAssertNil(reason)
        XCTAssertEqual(llm.callCount, 0)
    }

    func testEvaluate_WhenLLMThrowsCancellationError_ReturnsNil() async {
        let llm = MockLLMGenerator(error: CancellationError())
        let evaluator = LLMTriggerEvaluator(miniLLM: llm)

        let chunk = makeChunk(text: "I am still thinking...", isFinal: true)
        let reason = await evaluator.evaluate(chunk: chunk, context: [chunk])

        XCTAssertNil(reason)
        XCTAssertEqual(llm.callCount, 1)
    }

    func testEvaluate_WhenLLMThrowsURLErrorCancelled_ReturnsNil() async {
        let llm = MockLLMGenerator(error: URLError(.cancelled))
        let evaluator = LLMTriggerEvaluator(miniLLM: llm)

        let chunk = makeChunk(text: "Give me one second...", isFinal: true)
        let reason = await evaluator.evaluate(chunk: chunk, context: [chunk])

        XCTAssertNil(reason)
        XCTAssertEqual(llm.callCount, 1)
    }
    
    private func makeChunk(text: String, isFinal: Bool) -> TranscriptChunk {
        TranscriptChunk(
            text: text,
            speakerID: "Speaker:0",
            isFinal: isFinal,
            startAt: 1.0,
            endAt: 2.0
        )
    }
}

private final class MockLLMGenerator: LLMGenerator {
    let response: String?
    let error: Error?
    private(set) var callCount = 0
    
    init(response: String) {
        self.response = response
        self.error = nil
    }

    init(error: Error) {
        self.response = nil
        self.error = error
    }
    
    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        callCount += 1

        if let error {
            throw error
        }

        return response ?? ""
    }
}
