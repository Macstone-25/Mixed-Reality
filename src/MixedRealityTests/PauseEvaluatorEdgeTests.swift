import XCTest
@testable import MRCS

final class PauseEvaluatorEdgeTests: XCTestCase {
    func testEvaluate_ReturnsNil_WhenTaskCancelledDuringSleep() async throws {
        let experiment = try makeExperiment(triggerDelayMs: 0, pauseDurationMs: 30)
        let evaluator = PauseEvaluator(experiment: experiment)
        let chunk = makeChunk(text: "hello")

        let task = Task {
            await evaluator.evaluate(chunk: chunk, context: [])
        }
        task.cancel()
        let reason = await task.value

        XCTAssertNil(reason)
    }

    func testEvaluate_HandlesVerySmallDelayPauseValues() async throws {
        let pairs: [(Int, Int)] = [
            (1, 1),
            (1, 2),
            (2, 1),
            (2, 2)
        ]

        for (triggerDelayMs, pauseDurationMs) in pairs {
            let experiment = try makeExperiment(
                triggerDelayMs: triggerDelayMs,
                pauseDurationMs: pauseDurationMs
            )
            let evaluator = PauseEvaluator(experiment: experiment)
            let chunk = makeChunk(text: "hello")

            let reason = await evaluator.evaluate(chunk: chunk, context: [])

            guard case .longPause(let durationMs) = reason else {
                return XCTFail("Expected longPause reason")
            }
            XCTAssertEqual(durationMs, max(triggerDelayMs, pauseDurationMs))
        }
    }

    func testEvaluate_ReportedDurationAlwaysEqualsMaxOfPauseAndDelay() async throws {
        let pairs: [(Int, Int)] = [
            (0, 0),
            (0, 3),
            (3, 0),
            (4, 9),
            (9, 4),
            (10, 10)
        ]

        for (triggerDelayMs, pauseDurationMs) in pairs {
            let experiment = try makeExperiment(
                triggerDelayMs: triggerDelayMs,
                pauseDurationMs: pauseDurationMs
            )
            let evaluator = PauseEvaluator(experiment: experiment)
            let reason = await evaluator.evaluate(chunk: makeChunk(text: "sample"), context: [])

            guard case .longPause(let durationMs) = reason else {
                return XCTFail("Expected longPause reason")
            }
            XCTAssertEqual(durationMs, max(triggerDelayMs, pauseDurationMs))
        }
    }
}
