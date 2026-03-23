import XCTest
@testable import MRCS

final class TriggerServiceTests: XCTestCase {
    func testShouldSuppressDuplicateChunk_ForNearIdenticalReplay() {
        let last = makeChunk("hello there", isFinal: false, startAt: 0.6, endAt: 1.0)
        let current = makeChunk("hello there", isFinal: false, startAt: 0.7, endAt: 1.2)
        
        XCTAssertTrue(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldSuppressDuplicateChunk_ForFillerNearIdenticalReplay() {
        let last = makeChunk("um", isFinal: false, startAt: 0.0, endAt: 0.4)
        let current = makeChunk("um", isFinal: false, startAt: 0.1, endAt: 0.5)
        
        XCTAssertTrue(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldNotSuppressDuplicateChunk_WhenStartWindowDiffers() {
        let last = makeChunk("hello there", isFinal: false, startAt: 0.0, endAt: 1.0)
        let current = makeChunk("hello there", isFinal: false, startAt: 0.6, endAt: 1.2)
        
        XCTAssertFalse(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testShouldNotSuppressDuplicateChunk_WhenTextDiffers() {
        let last = makeChunk("hello there", isFinal: false, startAt: 0.6, endAt: 1.0)
        let current = makeChunk("hello again", isFinal: false, startAt: 0.7, endAt: 1.2)
        
        XCTAssertFalse(TriggerService.shouldSuppressDuplicateChunk(current, comparedTo: last))
    }
    
    func testBuildInterventionContext_AppendsTriggeringInterimChunk() {
        let finalChunk = makeChunk("Hello there.", isFinal: true, startAt: 0.0, endAt: 1.0)
        let interimChunk = makeChunk("um", isFinal: false, startAt: 1.2, endAt: 1.5)
        
        let context = TriggerService.buildInterventionContext(
            from: [finalChunk, interimChunk],
            triggeringChunk: interimChunk
        )
        
        XCTAssertEqual(context, [finalChunk, interimChunk])
    }
    
    private func makeChunk(
        _ text: String,
        isFinal: Bool,
        speakerID: String = "Speaker:1",
        startAt: Double,
        endAt: Double
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
