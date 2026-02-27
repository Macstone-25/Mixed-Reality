import Collections
import XCTest
@testable import MRCS

final class TranscriptChunkOrderingEdgeTests: XCTestCase {
    func testInsertSorted_ReverseSortedLargerSet_RemainsNondecreasingByStartAt() {
        var deque = Deque<TranscriptChunk>()
        let chunks = (0..<20).map { index in
            makeChunk(
                text: "chunk-\(index)",
                start: Double(index),
                end: Double(index) + 0.25
            )
        }.reversed()

        for chunk in chunks {
            deque.insertSorted(chunk)
        }

        XCTAssertEqual(deque.count, 20)
        for i in 0..<(deque.count - 1) {
            XCTAssertLessThanOrEqual(deque[i].startAt, deque[i + 1].startAt)
        }
    }

    func testInsertSorted_HandlesNegativeAndZeroTimestamps() {
        var deque = Deque<TranscriptChunk>()
        let chunks = [
            makeChunk(text: "pos", start: 2.0, end: 2.5),
            makeChunk(text: "zero", start: 0.0, end: 0.2),
            makeChunk(text: "neg2", start: -2.0, end: -1.5),
            makeChunk(text: "neg1", start: -1.0, end: -0.5)
        ]

        for chunk in chunks {
            deque.insertSorted(chunk)
        }

        XCTAssertEqual(Array(deque.map(\.startAt)), [-2.0, -1.0, 0.0, 2.0])
    }

    func testInsertSorted_HandlesDenseNearEqualTimestampsWithoutMisordering() {
        var deque = Deque<TranscriptChunk>()
        let chunks = [
            makeChunk(text: "a", start: 1.0002, end: 1.1),
            makeChunk(text: "b", start: 1.0, end: 1.1),
            makeChunk(text: "c", start: 1.0001, end: 1.1)
        ]

        for chunk in chunks {
            deque.insertSorted(chunk)
        }

        XCTAssertEqual(Array(deque.map(\.startAt)), [1.0, 1.0001, 1.0002])
    }

    func testInsertSorted_PreservesMultisetContentsAfterRepeatedInserts() {
        var deque = Deque<TranscriptChunk>()
        let inserted: [TranscriptChunk] = [
            makeChunk(text: "x", start: 3.0, end: 3.1),
            makeChunk(text: "y", start: 1.0, end: 1.1),
            makeChunk(text: "x", start: 3.0, end: 3.1),
            makeChunk(text: "z", start: -1.0, end: -0.9),
            makeChunk(text: "y", start: 1.0, end: 1.1),
            makeChunk(text: "w", start: 2.0, end: 2.1)
        ]

        for chunk in inserted {
            deque.insertSorted(chunk)
        }

        XCTAssertEqual(deque.count, inserted.count)

        let insertedCounts = Dictionary(inserted.map { ($0, 1) }, uniquingKeysWith: +)
        let dequeCounts = Dictionary(Array(deque).map { ($0, 1) }, uniquingKeysWith: +)
        XCTAssertEqual(dequeCounts, insertedCounts)

        for i in 0..<(deque.count - 1) {
            XCTAssertLessThanOrEqual(deque[i].startAt, deque[i + 1].startAt)
        }
    }
}
