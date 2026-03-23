import XCTest
@testable import MRCS

final class TriggerServiceTests: XCTestCase {
    func testShouldSuppressDuplicateChunk_ForNearIdenticalReplay() {
        let last = TranscriptChunk(text: "hello there", speakerID: "Speaker:1", isFinal: false, startAt: 0.6, endAt: 1.0)
        let current = TranscriptChunk(text: "hello there", speakerID: "Speaker:1", isFinal: false, startAt: 0.7, endAt: 1.2)
        
        XCTAssertTrue(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldSuppressDuplicateChunk_ForFillerNearIdenticalReplay() {
        let last = TranscriptChunk(text: "um", speakerID: "Speaker:1", isFinal: false, startAt: 0.0, endAt: 0.4)
        let current = TranscriptChunk(text: "um", speakerID: "Speaker:1", isFinal: false, startAt: 0.1, endAt: 0.5)
        
        XCTAssertTrue(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldNotSuppressDuplicateChunk_WhenStartWindowDiffers() {
        let last = TranscriptChunk(text: "hello there", speakerID: "Speaker:1", isFinal: false, startAt: 0.0, endAt: 1.0)
        let current = TranscriptChunk(text: "hello there", speakerID: "Speaker:1", isFinal: false, startAt: 0.6, endAt: 1.2)
        
        XCTAssertFalse(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldNotSuppressDuplicateChunk_WhenTextDiffers() {
        let last = TranscriptChunk(text: "hello there", speakerID: "Speaker:1", isFinal: false, startAt: 0.6, endAt: 1.0)
        let current = TranscriptChunk(text: "hello again", speakerID: "Speaker:1", isFinal: false, startAt: 0.7, endAt: 1.2)
        
        XCTAssertFalse(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testBuildInterventionContext_AppendsTriggeringInterimChunk() {
        let finalChunk = TranscriptChunk(text: "Hello there.", speakerID: "Speaker:1", isFinal: true, startAt: 0.0, endAt: 1.0)
        let interimChunk = TranscriptChunk(text: "um", speakerID: "Speaker:1", isFinal: false, startAt: 1.2, endAt: 1.5)
        
        let context = TriggerService.buildInterventionContext(
            from: [finalChunk, interimChunk],
            triggeringChunk: interimChunk
        )
        
        XCTAssertEqual(context, [finalChunk, interimChunk])
    }
}
