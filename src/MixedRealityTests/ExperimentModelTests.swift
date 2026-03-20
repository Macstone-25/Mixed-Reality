import XCTest
@testable import MRCS

final class ExperimentModelTests: XCTestCase {
    func testInit_ThrowsWhenNoLLMsSelected() {
        let config = makeConfigWithEmptyLLMs()

        do {
            _ = try ExperimentModel(config: config)
            XCTFail("Expected ExperimentModel init to throw")
        } catch let ExperimentError.insufficientOptions(message) {
            XCTAssertEqual(message, "No LLMs selected")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInit_ThrowsWhenNoMiniLLMsSelected() {
        let config = makeConfigWithEmptyMiniLLMs()

        do {
            _ = try ExperimentModel(config: config)
            XCTFail("Expected ExperimentModel init to throw")
        } catch let ExperimentError.insufficientOptions(message) {
            XCTAssertEqual(message, "No mini LLMs selected")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInit_ThrowsWhenNoTriggerEvaluatorsSelected() {
        let config = makeConfigWithEmptyTriggerStrategies()

        do {
            _ = try ExperimentModel(config: config)
            XCTFail("Expected ExperimentModel init to throw")
        } catch let ExperimentError.insufficientOptions(message) {
            XCTAssertEqual(message, "No trigger evaluators selected")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInit_UsesExactPinnedValuesWhenRangesAreFixed() throws {
        let config = makeConfig(
            triggerDelayMs: 1234,
            pauseDurationMs: 3456,
            triggerContext: 7,
            triggerCooldownMs: 8900,
            minTriggerEvaluators: 1,
            selectedStrategies: [.pauseEvaluator]
        )

        let experiment = try ExperimentModel(config: config)

        XCTAssertEqual(experiment.triggerContext, 7)
        XCTAssertEqual(experiment.triggerDelayMs, 1234)
        XCTAssertEqual(experiment.pauseDurationMs, 3456)
        XCTAssertEqual(experiment.triggerCooldown, 8.9, accuracy: 0.0001)
        XCTAssertEqual(experiment.triggerEvaluationStrategies, [.pauseEvaluator])
    }

    func testInit_ClampsMinTriggerEvaluatorsToAvailableStrategies() throws {
        let config = makeConfigForClampedTriggerEvaluators()
        let experiment = try ExperimentModel(config: config)

        XCTAssertEqual(experiment.triggerEvaluationStrategies.count, 1)
        XCTAssertEqual(experiment.triggerEvaluationStrategies.first, .pauseEvaluator)
    }

    func testInit_TriggerEvaluationStrategiesAreSubsetOfSelectedStrategies() throws {
        let selected: Set<TriggerEvaluationStrategy> = [.pauseEvaluator, .fillerEvaluator]
        let config = makeConfig(
            minTriggerEvaluators: 1,
            selectedStrategies: selected
        )

        let experiment = try ExperimentModel(config: config)

        XCTAssertFalse(experiment.triggerEvaluationStrategies.isEmpty)
        XCTAssertTrue(experiment.triggerEvaluationStrategies.allSatisfy { selected.contains($0) })
    }

    func testToJsonData_UsesSnakeCaseAndIncludesTriggerFields() throws {
        let config = makeConfig(
            triggerDelayMs: 1500,
            pauseDurationMs: 2500,
            triggerContext: 6,
            triggerCooldownMs: 5000,
            minTriggerEvaluators: 1,
            selectedStrategies: [.pauseEvaluator]
        )
        let experiment = try ExperimentModel(config: config)
        let data = try experiment.toJsonData()
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"trigger_context\""))
        XCTAssertTrue(json.contains("\"trigger_delay_ms\""))
        XCTAssertTrue(json.contains("\"trigger_cooldown\""))
        XCTAssertTrue(json.contains("\"pause_duration_ms\""))
    }
}
