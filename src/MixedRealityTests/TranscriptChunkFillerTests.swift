import XCTest
@testable import MRCS

final class TranscriptChunkFillerTests: XCTestCase {
    func testPlainText_RemovesPunctuationAndNormalizesCase() {
        let chunk = makeChunk(text: " Um, HELLO... world!!  ")

        XCTAssertEqual(chunk.plainText, "um hello world")
    }

    func testIsFiller_TrueForKnownFillerAndFalseOtherwise() {
        let fillerChunk = makeChunk(text: "UM!")
        let nonFillerChunk = makeChunk(text: "hello")

        XCTAssertTrue(fillerChunk.isFiller)
        XCTAssertFalse(nonFillerChunk.isFiller)
    }

    func testEndsWithFiller_DetectsFillerAtSentenceEnd() {
        let endsWithFiller = makeChunk(text: "Well um.")
        let doesNotEndWithFiller = makeChunk(text: "um hello")

        XCTAssertTrue(endsWithFiller.endsWithFiller)
        XCTAssertFalse(doesNotEndWithFiller.endsWithFiller)
    }

    func testWordCount_UsesNormalizedPlainText() {
        let chunk = makeChunk(text: "  Hello,   there...  UM  ")

        XCTAssertEqual(chunk.wordCount, 3)
    }
}
