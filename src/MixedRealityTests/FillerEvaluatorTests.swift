import XCTest
@testable import MRCS

final class FillerEvaluatorTests: XCTestCase {
    func testEvaluate_ReturnsNil_WhenContextTooShort() async {
        let evaluator = FillerEvaluator()
        let context = [
            makeChunk(text: "um"),
            makeChunk(text: "uh"),
            makeChunk(text: "hm")
        ]
        let chunk = makeChunk(text: "like")

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        XCTAssertNil(reason)
    }

    func testEvaluate_ReturnsNil_WhenCurrentChunkDoesNotEndWithFiller() async {
        let evaluator = FillerEvaluator()
        let context = [
            makeChunk(text: "um"),
            makeChunk(text: "uh"),
            makeChunk(text: "hm"),
            makeChunk(text: "like")
        ]
        let chunk = makeChunk(text: "I am done")

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        XCTAssertNil(reason)
    }

    func testEvaluate_ReturnsFillerReason_WhenCurrentAndTrailingContextAreFillers() async {
        let evaluator = FillerEvaluator()
        let context = [
            makeChunk(text: "hello"),
            makeChunk(text: "um"),
            makeChunk(text: "uh"),
            makeChunk(text: "hm")
        ]
        let chunk = makeChunk(text: "like")

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        guard case .filler(let words) = reason else {
            return XCTFail("Expected filler reason")
        }
        XCTAssertEqual(words, "um, uh, hm, like")
    }

    func testEvaluate_ChunkEqualsLast_DoesNotDuplicateFinalWord() async {
        let evaluator = FillerEvaluator()
        let context = [
            makeChunk(text: "um."),
            makeChunk(text: "uh!"),
            makeChunk(text: "hm,"),
            makeChunk(text: "LIKE?")
        ]
        let chunk = context.last!

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        guard case .filler(let words) = reason else {
            return XCTFail("Expected filler reason")
        }
        XCTAssertEqual(words, "um, uh, hm, like")
        XCTAssertEqual(words.components(separatedBy: ", ").count, 4)
    }

    func testEvaluate_ChunkNotLast_AppendsCurrentChunkWord() async {
        let evaluator = FillerEvaluator()
        let context = [
            makeChunk(text: "start"),
            makeChunk(text: "um"),
            makeChunk(text: "uh"),
            makeChunk(text: "hm")
        ]
        let chunk = makeChunk(text: "like")

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        guard case .filler(let words) = reason else {
            return XCTFail("Expected filler reason")
        }
        XCTAssertEqual(words, "um, uh, hm, like")
    }
}
