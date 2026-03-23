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
        let chunk = makeChunk("I was umm um um trying to explain", isFinal: true)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: [])
        
        XCTAssertEqual(reason?.description, "Filler words (um, um, um)")
    }
    
    func testEvaluate_TriggersForRepeatedAndWithinChunk() async {
        let chunk = makeChunk("and, and and we kept going", isFinal: true)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: [])
        
        XCTAssertEqual(reason?.description, "Filler words (and, and, and)")
    }
    
    func testEvaluate_DoesNotTriggerForOnlyTwoRepeatedFillersWithinChunk() async {
        let chunk = makeChunk("I was um um trying to explain", isFinal: true)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: [])
        
        XCTAssertNil(reason)
    }
    
    func testEvaluate_TriggersForRepeatedFillerBurstAcrossDistinctChunks() async {
        let context = [
            makeChunk("um", isFinal: false, startAt: 0.0, endAt: 0.3),
            makeChunk("um", isFinal: false, startAt: 0.7, endAt: 1.0)
        ]
        let chunk = makeChunk("umm", isFinal: false, startAt: 1.3, endAt: 1.6)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: context)
        
        XCTAssertEqual(reason?.description, "Filler words (um, um, um)")
    }
    
    func testEvaluate_DoesNotTriggerWhenBurstGapIsTooLarge() async {
        let context = [
            makeChunk("um", isFinal: false, startAt: 0.0, endAt: 0.3),
            makeChunk("um", isFinal: false, startAt: 4.1, endAt: 4.4)
        ]
        let chunk = makeChunk("um", isFinal: false, startAt: 4.8, endAt: 5.1)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: context)
        
        XCTAssertNil(reason)
    }
    
    func testEvaluate_DoesNotTriggerWhenBurstCrossesSpeakers() async {
        let context = [
            makeChunk("um", isFinal: false, speakerID: "Speaker:1", startAt: 0.0, endAt: 0.3),
            makeChunk("um", isFinal: false, speakerID: "Speaker:2", startAt: 0.6, endAt: 0.9)
        ]
        let chunk = makeChunk("um", isFinal: false, speakerID: "Speaker:1", startAt: 1.2, endAt: 1.5)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: context)
        
        XCTAssertNil(reason)
    }
    
    func testEvaluate_DoesNotCountExactReplayDuplicatesAcrossChunks() async {
        let context = [
            makeChunk("um", isFinal: false, startAt: 0.0, endAt: 0.4),
            makeChunk("um", isFinal: false, startAt: 0.0, endAt: 0.4),
            makeChunk("um", isFinal: false, startAt: 0.0, endAt: 0.4)
        ]
        let chunk = makeChunk("um", isFinal: false, startAt: 1.0, endAt: 1.4)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: context)
        
        XCTAssertNil(reason)
    }
    
    func testEvaluate_TriggersForDistinctRapidFillersWithReplayNoise() async {
        let context = [
            makeChunk("um", isFinal: false, startAt: 0.0, endAt: 0.4),
            makeChunk("um", isFinal: false, startAt: 0.0, endAt: 0.4),
            makeChunk("um", isFinal: false, startAt: 0.8, endAt: 1.2)
        ]
        let chunk = makeChunk("um", isFinal: false, startAt: 1.6, endAt: 2.0)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: context)
        
        XCTAssertEqual(reason?.description, "Filler words (um, um, um)")
    }
    
    func testEvaluate_DoesNotTreatAndAsChunkEndingFiller() async {
        let context = [
            makeChunk("we stopped and.", isFinal: true, startAt: 0, endAt: 1),
            makeChunk("then restarted and.", isFinal: true, startAt: 1, endAt: 2)
        ]
        let chunk = makeChunk("finished again and.", isFinal: true, startAt: 2, endAt: 3)
        
        let reason = await evaluator.evaluate(chunk: chunk, context: context)
        
        XCTAssertNil(reason)
    }
    
    private func makeChunk(
        _ text: String,
        isFinal: Bool,
        speakerID: String = "Speaker:1",
        startAt: Double = 0,
        endAt: Double = 1
    ) -> TranscriptChunk {
        TranscriptChunk(
            text: text,
            speakerID: speakerID,
            isFinal: isFinal,
            startAt: startAt,
            endAt: endAt
        )
    }
}
