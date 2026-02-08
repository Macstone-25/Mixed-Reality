import XCTest
import Collections
@testable import MixedReality

final class TranscriptChunkOrderingTests: XCTestCase {
    
    func testInsertSorted_ChunksInOrder() throws {
        var deque = Deque<TranscriptChunk>()
        
        let chunk1 = TranscriptChunk(text: "First", speakerID: "A", isFinal: true, startAt: 1.0, endAt: 2.0)
        let chunk2 = TranscriptChunk(text: "Second", speakerID: "A", isFinal: true, startAt: 2.5, endAt: 3.5)
        let chunk3 = TranscriptChunk(text: "Third", speakerID: "B", isFinal: true, startAt: 4.0, endAt: 5.0)
        
        deque.insertSorted(chunk1)
        deque.insertSorted(chunk2)
        deque.insertSorted(chunk3)
        
        XCTAssertEqual(deque.count, 3)
        XCTAssertEqual(deque[0].text, "First")
        XCTAssertEqual(deque[1].text, "Second")
        XCTAssertEqual(deque[2].text, "Third")
    }
    
    func testInsertSorted_ChunksOutOfOrder() throws {
        var deque = Deque<TranscriptChunk>()
        
        let chunk1 = TranscriptChunk(text: "First", speakerID: "A", isFinal: true, startAt: 1.0, endAt: 2.0)
        let chunk2 = TranscriptChunk(text: "Second", speakerID: "B", isFinal: true, startAt: 2.5, endAt: 3.5)
        let chunk3 = TranscriptChunk(text: "Third", speakerID: "A", isFinal: true, startAt: 4.0, endAt: 5.0)
        
        // Insert in wrong order: chunk3, chunk1, chunk2
        deque.insertSorted(chunk3)
        deque.insertSorted(chunk1)
        deque.insertSorted(chunk2)
        
        // Should still be sorted correctly
        XCTAssertEqual(deque.count, 3)
        XCTAssertEqual(deque[0].text, "First")
        XCTAssertEqual(deque[1].text, "Second")
        XCTAssertEqual(deque[2].text, "Third")
        XCTAssertEqual(deque[0].startAt, 1.0)
        XCTAssertEqual(deque[1].startAt, 2.5)
        XCTAssertEqual(deque[2].startAt, 4.0)
    }
    
    func testInsertSorted_ReproduceBugScenario() throws {
        // Reproduce the bug scenario from the issue:
        // Chunk from 90.1-91.4 is finalized before chunk from 89.6-90.3
        var deque = Deque<TranscriptChunk>()
        
        let laterChunk = TranscriptChunk(text: "Later", speakerID: "A", isFinal: true, startAt: 90.1, endAt: 91.4)
        let earlierChunk = TranscriptChunk(text: "Earlier", speakerID: "B", isFinal: true, startAt: 89.6, endAt: 90.3)
        
        // Insert later chunk first (as described in the bug)
        deque.insertSorted(laterChunk)
        deque.insertSorted(earlierChunk)
        
        // Should be sorted correctly with earlier chunk first
        XCTAssertEqual(deque.count, 2)
        XCTAssertEqual(deque[0].text, "Earlier")
        XCTAssertEqual(deque[1].text, "Later")
        XCTAssertEqual(deque[0].startAt, 89.6)
        XCTAssertEqual(deque[1].startAt, 90.1)
    }
    
    func testInsertSorted_MultipleOutOfOrderChunks() throws {
        var deque = Deque<TranscriptChunk>()
        
        let chunks = [
            TranscriptChunk(text: "5th", speakerID: "A", isFinal: true, startAt: 5.0, endAt: 6.0),
            TranscriptChunk(text: "2nd", speakerID: "B", isFinal: true, startAt: 2.0, endAt: 3.0),
            TranscriptChunk(text: "4th", speakerID: "A", isFinal: true, startAt: 4.0, endAt: 5.0),
            TranscriptChunk(text: "1st", speakerID: "B", isFinal: true, startAt: 1.0, endAt: 2.0),
            TranscriptChunk(text: "3rd", speakerID: "A", isFinal: true, startAt: 3.0, endAt: 4.0),
        ]
        
        // Insert in random order
        for chunk in chunks {
            deque.insertSorted(chunk)
        }
        
        // Verify they are sorted correctly
        XCTAssertEqual(deque.count, 5)
        XCTAssertEqual(deque[0].text, "1st")
        XCTAssertEqual(deque[1].text, "2nd")
        XCTAssertEqual(deque[2].text, "3rd")
        XCTAssertEqual(deque[3].text, "4th")
        XCTAssertEqual(deque[4].text, "5th")
        
        // Verify timestamps are in order
        for i in 0..<deque.count-1 {
            XCTAssertLessThan(deque[i].startAt, deque[i+1].startAt)
        }
    }
    
    func testInsertSorted_OverlappingChunks() throws {
        // Test chunks that overlap in time (multiple speakers)
        var deque = Deque<TranscriptChunk>()
        
        let chunk1 = TranscriptChunk(text: "Speaker A starts", speakerID: "A", isFinal: true, startAt: 1.0, endAt: 3.0)
        let chunk2 = TranscriptChunk(text: "Speaker B interrupts", speakerID: "B", isFinal: true, startAt: 2.0, endAt: 4.0)
        let chunk3 = TranscriptChunk(text: "Speaker A continues", speakerID: "A", isFinal: true, startAt: 3.5, endAt: 5.0)
        
        // Insert in reverse order
        deque.insertSorted(chunk3)
        deque.insertSorted(chunk2)
        deque.insertSorted(chunk1)
        
        // Should be sorted by startAt
        XCTAssertEqual(deque.count, 3)
        XCTAssertEqual(deque[0].startAt, 1.0)
        XCTAssertEqual(deque[1].startAt, 2.0)
        XCTAssertEqual(deque[2].startAt, 3.5)
    }
    
    func testInsertSorted_EmptyDeque() throws {
        var deque = Deque<TranscriptChunk>()
        
        let chunk = TranscriptChunk(text: "First", speakerID: "A", isFinal: true, startAt: 1.0, endAt: 2.0)
        deque.insertSorted(chunk)
        
        XCTAssertEqual(deque.count, 1)
        XCTAssertEqual(deque[0].text, "First")
    }
    
    func testInsertSorted_IdenticalStartTimes() throws {
        // Edge case: chunks with identical start times
        var deque = Deque<TranscriptChunk>()
        
        let chunk1 = TranscriptChunk(text: "First", speakerID: "A", isFinal: true, startAt: 1.0, endAt: 2.0)
        let chunk2 = TranscriptChunk(text: "Second", speakerID: "B", isFinal: true, startAt: 1.0, endAt: 2.5)
        
        deque.insertSorted(chunk1)
        deque.insertSorted(chunk2)
        
        // Both should be in the deque (order between identical startAt is not guaranteed but both should be present)
        XCTAssertEqual(deque.count, 2)
        XCTAssertTrue(deque.contains(where: { $0.text == "First" }))
        XCTAssertTrue(deque.contains(where: { $0.text == "Second" }))
    }
}
