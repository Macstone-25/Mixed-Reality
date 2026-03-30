import XCTest
import AVFoundation
@testable import MRCS

final class SpeechServiceLoggingTests: XCTestCase {
    func testPreConnectPCMBuffer_DrainPreservesFrameOrder() {
        let buffer = makeLeakedPreConnectBuffer(
            sampleRate: 1_000,
            channelCount: 1,
            durationSeconds: 2.0
        )
        
        let first = Data([0x01])
        let second = Data([0x02])
        let third = Data([0x03])
        
        _ = buffer.enqueue(first)
        _ = buffer.enqueue(second)
        _ = buffer.enqueue(third)
        
        XCTAssertEqual(buffer.drain(), [first, second, third])
        XCTAssertTrue(buffer.drain().isEmpty)
    }
    
    func testPreConnectPCMBuffer_DropsOldestFramesWhenCapacityIsExceeded() {
        let buffer = makeLeakedPreConnectBuffer(
            sampleRate: 1_000,
            channelCount: 1,
            durationSeconds: 1.0
        )
        
        let first = Data(repeating: 0xAA, count: 1_000)
        let second = Data(repeating: 0xBB, count: 1_000)
        let third = Data(repeating: 0xCC, count: 1_000)
        
        _ = buffer.enqueue(first)
        _ = buffer.enqueue(second)
        _ = buffer.enqueue(third)
        
        XCTAssertEqual(buffer.drain(), [second, third])
    }
    
    private func makeLeakedPreConnectBuffer(
        sampleRate: Double,
        channelCount: AVAudioChannelCount,
        durationSeconds: TimeInterval
    ) -> PreConnectPCMBuffer {
        let unmanaged = Unmanaged.passRetained(
            PreConnectPCMBuffer(
                sampleRate: sampleRate,
                channelCount: channelCount,
                durationSeconds: durationSeconds
            )
        )
        
        return unmanaged.takeUnretainedValue()
    }
}
