import XCTest
@testable import MRCS

final class TriggerServiceLLMFallbackTests: XCTestCase {
    func testEvaluateWithRace_WhenEvaluatorTriggers_ReturnsFirstReason() async {
        let chunk = makeChunk()

        let slowNilEvaluator = StubEvaluator(result: nil, delayMs: 50)
        let fastTriggeringEvaluator = StubEvaluator(result: .filler(words: "um, uh, hmm"), delayMs: 1)
        let slowerTriggeringEvaluator = StubEvaluator(
            result: .llmSuggested(rationale: "Should not win race"),
            delayMs: 75
        )

        let reason = await TriggerService.evaluateWithRace(
            chunk: chunk,
            context: [chunk],
            evaluators: [slowNilEvaluator, fastTriggeringEvaluator, slowerTriggeringEvaluator]
        )

        guard case .filler(let words)? = reason else {
            return XCTFail("Expected filler reason")
        }

        XCTAssertEqual(words, "um, uh, hmm")
    }

    func testEvaluateWithRace_WhenAllEvaluatorsReturnNil_ReturnsNil() async {
        let chunk = makeChunk()

        let reason = await TriggerService.evaluateWithRace(
            chunk: chunk,
            context: [chunk],
            evaluators: [StubEvaluator(result: nil), StubEvaluator(result: nil, delayMs: 5)]
        )

        XCTAssertNil(reason)
    }

    func testEvaluateWithRace_WhenNoEvaluatorsConfigured_ReturnsNil() async {
        let chunk = makeChunk()

        let reason = await TriggerService.evaluateWithRace(
            chunk: chunk,
            context: [chunk],
            evaluators: []
        )

        XCTAssertNil(reason)
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
    private let delayNanoseconds: UInt64

    init(result: InterventionReason?, delayMs: UInt64 = 0) {
        self.result = result
        self.delayNanoseconds = delayMs * 1_000_000
    }

    func evaluate(chunk: TranscriptChunk, context: [TranscriptChunk]) async -> InterventionReason? {
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return result
    }
}
