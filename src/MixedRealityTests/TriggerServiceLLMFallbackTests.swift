import XCTest
@testable import MRCS

final class TriggerServiceLLMFallbackTests: XCTestCase {
    func testEvaluateWithFallback_WhenHeuristicTriggers_DoesNotRunLLM() async {
        let chunk = makeChunk()
        
        let heuristic = StubEvaluator(result: .filler(words: "um, uh, hmm"))
        let llm = StubEvaluator(result: .llmSuggested(rationale: "LLM should not run"))
        
        let reason = await TriggerService.evaluateWithFallback(
            chunk: chunk,
            context: [chunk],
            heuristicEvaluators: [heuristic],
            llmEvaluator: llm
        )
        
        guard case .filler(let words)? = reason else {
            return XCTFail("Expected filler reason")
        }
        
        let heuristicCallCount = await heuristic.callCount()
        let llmCallCount = await llm.callCount()
        
        XCTAssertEqual(words, "um, uh, hmm")
        XCTAssertEqual(heuristicCallCount, 1)
        XCTAssertEqual(llmCallCount, 0)
    }
    
    func testEvaluateWithFallback_WhenHeuristicsDoNotTrigger_RunsLLM() async {
        let chunk = makeChunk()
        
        let heuristic = StubEvaluator(result: nil)
        let llm = StubEvaluator(result: .llmSuggested(rationale: "Conversation appears stalled"))
        
        let reason = await TriggerService.evaluateWithFallback(
            chunk: chunk,
            context: [chunk],
            heuristicEvaluators: [heuristic],
            llmEvaluator: llm
        )
        
        guard case .llmSuggested(let rationale)? = reason else {
            return XCTFail("Expected llmSuggested reason")
        }
        
        let heuristicCallCount = await heuristic.callCount()
        let llmCallCount = await llm.callCount()
        
        XCTAssertEqual(rationale, "Conversation appears stalled")
        XCTAssertEqual(heuristicCallCount, 1)
        XCTAssertEqual(llmCallCount, 1)
    }
    
    func testEvaluateWithFallback_WhenNoLLMEvaluatorConfigured_ReturnsNil() async {
        let chunk = makeChunk()
        
        let heuristic = StubEvaluator(result: nil)
        
        let reason = await TriggerService.evaluateWithFallback(
            chunk: chunk,
            context: [chunk],
            heuristicEvaluators: [heuristic],
            llmEvaluator: nil
        )
        
        let heuristicCallCount = await heuristic.callCount()
        
        XCTAssertNil(reason)
        XCTAssertEqual(heuristicCallCount, 1)
    }
    
    private func makeChunk() -> TranscriptChunk {
        TranscriptChunk(
            text: "Can you remind me what I was saying?",
            speakerID: "Speaker:0",
            isFinal: true,
            startAt: 5.0,
            endAt: 6.2
        )
    }
}

private actor StubEvaluator: TriggerEvaluator {
    private let result: InterventionReason?
    private var count: Int = 0
    
    init(result: InterventionReason?) {
        self.result = result
    }
    
    func evaluate(chunk: TranscriptChunk, context: [TranscriptChunk]) async -> InterventionReason? {
        count += 1
        return result
    }
    
    func callCount() -> Int {
        count
    }
}
