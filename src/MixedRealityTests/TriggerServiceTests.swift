import XCTest
@testable import MRCS

final class TriggerServiceTests: XCTestCase {
    func testShouldSuppressDuplicateChunk_ForNonFillerNearDuplicate() {
        let last = makeChunk("hello there", endAt: 1.0)
        let current = makeChunk("hello there", endAt: 1.3)
        
        XCTAssertTrue(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldNotSuppressDuplicateChunk_ForFillerNearDuplicate() {
        let last = makeChunk("um", endAt: 1.0)
        let current = makeChunk("um", endAt: 1.3)
        
        XCTAssertFalse(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldNotSuppressDuplicateChunk_WhenTimeGapIsLarge() {
        let last = makeChunk("hello there", endAt: 1.0)
        let current = makeChunk("hello there", endAt: 1.6)
        
        XCTAssertFalse(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldNotSuppressDuplicateChunk_WhenTextDiffers() {
        let last = makeChunk("hello there", endAt: 1.0)
        let current = makeChunk("hello again", endAt: 1.2)
        
        XCTAssertFalse(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    private func makeChunk(_ text: String, endAt: Double) -> TranscriptChunk {
        TranscriptChunk(
            text: text,
            speakerID: "Speaker:1",
            isFinal: false,
            startAt: max(0, endAt - 0.4),
            endAt: endAt
        )
    }
}
