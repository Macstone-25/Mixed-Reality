import XCTest
@testable import MRCS

final class FillerEvaluatorTests: XCTestCase {
    private let evaluator = FillerEvaluator()
    
    func testEvaluate_TriggersWhenThreeSequentialChunksEndWithFiller() async {
        let context = [
            makeChunk("I think um", isFinal: true, startAt: 0, endAt: 1),
            makeChunk("maybe uh", isFinal: true, startAt: 1, endAt: 2)
        ]
        let chunk = makeChunk("let me see hm", isFinal: true, startAt: 2, endAt: 3)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: context)
        
        XCTAssertEqual(reason?.description, "Filler words (um, uh, hm)")
    }
    
    func testEvaluate_TriggersForRepeatedFillerWordWithinChunk() async {
        let chunk = makeChunk("I was um um um trying to explain", isFinal: true)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: [])
        
        XCTAssertEqual(reason?.description, "Filler words (um, um, um)")
    }
    
    func testEvaluate_TriggersForRepeatedFillerWordWithPunctuation() async {
        let chunk = makeChunk("I was, um, um, um, trying to explain", isFinal: true)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: [])
        
        XCTAssertEqual(reason?.description, "Filler words (um, um, um)")
    }
    
    func testEvaluate_TriggersForRepeatedAndWithinChunk() async {
        let chunk = makeChunk("and, and and we kept going", isFinal: true)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: [])
        
        XCTAssertEqual(reason?.description, "Filler words (and, and, and)")
    }
    
    func testEvaluate_DoesNotTreatAndAsChunkEndingFiller() async {
        let context = [
            makeChunk("we stopped and", isFinal: true, startAt: 0, endAt: 1),
            makeChunk("then restarted and", isFinal: true, startAt: 1, endAt: 2)
        ]
        let chunk = makeChunk("finished again and", isFinal: true, startAt: 2, endAt: 3)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: context)
        
        XCTAssertNil(reason)
    }
    
    func testEvaluate_DoesNotTriggerForOnlyTwoRepeatedFillers() async {
        let chunk = makeChunk("I was um um trying to explain", isFinal: true)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: [])
        
        XCTAssertNil(reason)
    }
    
    func testEvaluate_DoesNotTriggerWhenRepeatsAreNotConsecutive() async {
        let chunk = makeChunk("I was um trying um to explain um clearly", isFinal: true)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: [])
        
        XCTAssertNil(reason)
    }
    
    private func makeChunk(
        _ text: String,
        isFinal: Bool,
        startAt: Double = 0,
        endAt: Double = 1
    ) -> TranscriptChunk {
        TranscriptChunk(
            text: text,
            speakerID: "Speaker:1",
            isFinal: isFinal,
            startAt: startAt,
            endAt: endAt
        )
    }
}
