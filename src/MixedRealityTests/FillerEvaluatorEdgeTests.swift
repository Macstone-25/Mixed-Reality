import XCTest
@testable import MRCS

final class FillerEvaluatorEdgeTests: XCTestCase {
    func testEvaluate_UsesCurrentChunkAtBoundaryWhenTrailingFillersReachThreshold() async {
        let evaluator = FillerEvaluator(chunksToCheck: 3)
        let context = [
            makeChunk(text: "um"),
            makeChunk(text: "uh"),
            makeChunk(text: "hm")
        ]
        let chunk = makeChunk(text: "like")

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        guard case .filler(let words) = reason else {
            return XCTFail("Expected filler reason")
        }
        XCTAssertEqual(words, "uh, hm, like")
    }

    func testEvaluate_ReturnsNil_WhenOneTrailingContextChunkIsNotFiller() async {
        let evaluator = FillerEvaluator(chunksToCheck: 3)
        let context = [
            makeChunk(text: "start"),
            makeChunk(text: "um"),
            makeChunk(text: "not-filler"),
            makeChunk(text: "hm")
        ]
        let chunk = makeChunk(text: "like")

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        XCTAssertNil(reason)
    }

    func testEvaluate_NormalizesPunctuationNewlinesAndCaseInOutputWords() async {
        let evaluator = FillerEvaluator(chunksToCheck: 3)
        let context = [
            makeChunk(text: "start"),
            makeChunk(text: "UM,\n"),
            makeChunk(text: "Uh!"),
            makeChunk(text: "hM??")
        ]
        let chunk = makeChunk(text: "LiKe...")

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        guard case .filler(let words) = reason else {
            return XCTFail("Expected filler reason")
        }
        XCTAssertEqual(words, "uh, hm, like")
    }

    func testEvaluate_CustomChunksToCheckTwo_PositiveAndNegativeCases() async {
        let evaluator = FillerEvaluator(chunksToCheck: 2)
        let positiveContext = [
            makeChunk(text: "start"),
            makeChunk(text: "uh"),
            makeChunk(text: "hm")
        ]
        let positiveChunk = makeChunk(text: "um")

        let positiveReason = await evaluator.evaluate(chunk: positiveChunk, context: positiveContext)

        guard case .filler(let words) = positiveReason else {
            return XCTFail("Expected filler reason for positive case")
        }
        XCTAssertEqual(words, "hm, um")

        let negativeContext = [
            makeChunk(text: "start"),
            makeChunk(text: "uh"),
            makeChunk(text: "hello")
        ]
        let negativeChunk = makeChunk(text: "um")

        let negativeReason = await evaluator.evaluate(chunk: negativeChunk, context: negativeContext)
        XCTAssertNil(negativeReason)
    }

    func testEvaluate_FillerOutputOrderMatchesTrailingContextOrder() async {
        let evaluator = FillerEvaluator(chunksToCheck: 3)
        let context = [
            makeChunk(text: "prefix"),
            makeChunk(text: "ah"),
            makeChunk(text: "er"),
            makeChunk(text: "uh")
        ]
        let chunk = makeChunk(text: "hm")

        let reason = await evaluator.evaluate(chunk: chunk, context: context)

        guard case .filler(let words) = reason else {
            return XCTFail("Expected filler reason")
        }
        XCTAssertEqual(words, "er, uh, hm")
    }
}
