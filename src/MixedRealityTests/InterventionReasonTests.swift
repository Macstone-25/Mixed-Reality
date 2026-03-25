import XCTest
@testable import MRCS

final class InterventionReasonTests: XCTestCase {
    func testDescription_LongPauseFormatting() {
        let reason = InterventionReason.longPause(durationMs: 3500)

        XCTAssertEqual(reason.description, "Long pause (3.5s)")
    }

    func testDescription_FillerFormatting() {
        let reason = InterventionReason.filler(words: "um, uh, hm")

        XCTAssertEqual(reason.description, "Filler words (um, uh, hm)")
    }

    func testDescription_LlmSuggestedPassthrough() {
        let reason = InterventionReason.llmSuggested(rationale: "Ask a follow-up question")

        XCTAssertEqual(reason.description, "Ask a follow-up question")
    }

    func testCodableRoundTrip_LongPause() throws {
        let decoded = try roundTrip(.longPause(durationMs: 4200))

        guard case .longPause(let durationMs) = decoded else {
            return XCTFail("Expected longPause case after round trip")
        }
        XCTAssertEqual(durationMs, 4200)
    }

    func testCodableRoundTrip_Filler() throws {
        let decoded = try roundTrip(.filler(words: "um, uh"))

        guard case .filler(let words) = decoded else {
            return XCTFail("Expected filler case after round trip")
        }
        XCTAssertEqual(words, "um, uh")
    }

    func testCodableRoundTrip_LlmSuggested() throws {
        let decoded = try roundTrip(.llmSuggested(rationale: "Try a new topic"))

        guard case .llmSuggested(let rationale) = decoded else {
            return XCTFail("Expected llmSuggested case after round trip")
        }
        XCTAssertEqual(rationale, "Try a new topic")
    }

    private func roundTrip(_ reason: InterventionReason) throws -> InterventionReason {
        let data = try JSONEncoder().encode(reason)
        return try JSONDecoder().decode(InterventionReason.self, from: data)
    }
}
