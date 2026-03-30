import XCTest
@testable import MRCS

final class FillerEvaluatorTests: XCTestCase {
    private let evaluator = FillerEvaluator()

    func testEvaluate_TriggersWhenThreeSequentialChunksEndWithFiller() async {
        let context = [
            makeChunk(text: "I think um", isFinal: true, start: 0, end: 1),
            makeChunk(text: "maybe uh", isFinal: true, start: 1, end: 2)
        ]
        let chunk = makeChunk(text: "let me see hm", isFinal: true, start: 2, end: 3)

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        XCTAssertEqual(reason?.description, "Filler words (um, uh, hm)")
    }

    func testEvaluate_TriggersForRepeatedFillerWordWithinChunk() async {
        let chunk = makeChunk(text: "I was umm um um trying to explain", isFinal: true)

        let reason = await evaluator.evaluate(chunk: chunk, context: [])

        XCTAssertEqual(reason?.description, "Filler words (um, um, um)")
    }

    func testEvaluate_TriggersForRepeatedAndWithinChunk() async {
        let chunk = makeChunk(text: "and, and and we kept going", isFinal: true)

        let reason = await evaluator.evaluate(chunk: chunk, context: [])

        XCTAssertEqual(reason?.description, "Filler words (and, and, and)")
    }

    func testEvaluate_DoesNotTriggerForOnlyTwoRepeatedFillersWithinChunk() async {
        let chunk = makeChunk(text: "I was um um trying to explain", isFinal: true)

        let reason = await evaluator.evaluate(chunk: chunk, context: [])

        XCTAssertNil(reason)
    }

    func testEvaluate_TriggersForRepeatedFillerBurstAcrossDistinctChunks() async {
        let context = [
            makeChunk(text: "um", speaker: "Speaker:1", isFinal: false, start: 0.0, end: 0.3),
            makeChunk(text: "um", speaker: "Speaker:1", isFinal: false, start: 0.7, end: 1.0)
        ]
        let chunk = makeChunk(text: "umm", speaker: "Speaker:1", isFinal: false, start: 1.3, end: 1.6)

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        XCTAssertEqual(reason?.description, "Filler words (um, um, um)")
    }

    func testEvaluate_DoesNotTriggerWhenBurstGapIsTooLarge() async {
        let context = [
            makeChunk(text: "um", speaker: "Speaker:1", isFinal: false, start: 0.0, end: 0.3),
            makeChunk(text: "um", speaker: "Speaker:1", isFinal: false, start: 4.1, end: 4.4)
        ]
        let chunk = makeChunk(text: "um", speaker: "Speaker:1", isFinal: false, start: 4.8, end: 5.1)

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        XCTAssertNil(reason)
    }

    func testEvaluate_DoesNotTriggerWhenBurstCrossesSpeakers() async {
        let context = [
            makeChunk(text: "um", speaker: "Speaker:1", isFinal: false, start: 0.0, end: 0.3),
            makeChunk(text: "um", speaker: "Speaker:2", isFinal: false, start: 0.6, end: 0.9)
        ]
        let chunk = makeChunk(text: "um", speaker: "Speaker:1", isFinal: false, start: 1.2, end: 1.5)

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        XCTAssertNil(reason)
    }

    func testEvaluate_DoesNotTreatAndAsChunkEndingFiller() async {
        let context = [
            makeChunk(text: "we stopped and.", isFinal: true, start: 0, end: 1),
            makeChunk(text: "then restarted and.", isFinal: true, start: 1, end: 2)
        ]
        let chunk = makeChunk(text: "finished again and.", isFinal: true, start: 2, end: 3)

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        XCTAssertNil(reason)
    }
}
