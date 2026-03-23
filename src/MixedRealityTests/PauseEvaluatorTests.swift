import XCTest
@testable import MRCS

final class PauseEvaluatorTests: XCTestCase {
    func testEvaluate_ReportsPauseDuration_WhenEqualToTriggerDelay() async throws {
        let experiment = try makeExperiment(triggerDelayMs: 0, pauseDurationMs: 0)
        let evaluator = PauseEvaluator(experiment: experiment)
        let chunk = makeChunk(text: "hello")

        let reason = await evaluator.evaluate(chunk: chunk, context: [])

        guard case .longPause(let durationMs) = reason else {
            return XCTFail("Expected longPause reason")
        }
        XCTAssertEqual(durationMs, 0)
    }

    func testEvaluate_UsesTriggerDelay_WhenPauseIsLessThanDelay() async throws {
        let experiment = try makeExperiment(triggerDelayMs: 10, pauseDurationMs: 5)
        let evaluator = PauseEvaluator(experiment: experiment)
        let chunk = makeChunk(text: "hello")

        let reason = await evaluator.evaluate(chunk: chunk, context: [])

        guard case .longPause(let durationMs) = reason else {
            return XCTFail("Expected longPause reason")
        }
        XCTAssertEqual(durationMs, 10)
    }

    func testEvaluate_UsesPauseDuration_WhenPauseIsGreaterThanDelay() async throws {
        let experiment = try makeExperiment(triggerDelayMs: 5, pauseDurationMs: 6)
        let evaluator = PauseEvaluator(experiment: experiment)
        let chunk = makeChunk(text: "hello")

        let reason = await evaluator.evaluate(chunk: chunk, context: [])

        guard case .longPause(let durationMs) = reason else {
            return XCTFail("Expected longPause reason")
        }
        XCTAssertEqual(durationMs, 6)
    }
}
