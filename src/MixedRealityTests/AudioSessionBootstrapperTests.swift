import AVFoundation
import XCTest
@testable import MRCS

final class AudioSessionBootstrapperTests: XCTestCase {
    func testPrewarm_ConfiguresSessionInExpectedOrder() async throws {
        let recorder = CallRecorder()
        let bootstrapper = AudioSessionBootstrapper(
            permissionRequester: {
                await recorder.record("requestPermission")
                return true
            },
            sessionConfigurator: { _ in
                await recorder.record("setCategory")
                await recorder.record("setPreferredSampleRate")
                await recorder.record("setPreferredIOBufferDuration")
                await recorder.record("setActive")
            },
            sleepFn: { _ in },
            maxFormatResolutionAttempts: 3,
            formatRetryDelayNanoseconds: 1
        )

        try await bootstrapper.prewarm(preferredSampleRate: 48_000)
        let calls = await recorder.values()

        XCTAssertEqual(
            calls,
            [
                "requestPermission",
                "setCategory",
                "setPreferredSampleRate",
                "setPreferredIOBufferDuration",
                "setActive"
            ]
        )
    }

    func testResolveInputFormat_RetriesUntilValidFormat() async throws {
        let sleepCounter = Counter()
        let bootstrapper = AudioSessionBootstrapper(
            permissionRequester: { true },
            sessionConfigurator: { _ in },
            sleepFn: { _ in await sleepCounter.increment() },
            maxFormatResolutionAttempts: 3,
            formatRetryDelayNanoseconds: 1
        )

        let invalidFormat = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 0, channels: 1)
        )
        let validFormat = try XCTUnwrap(
            AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)
        )
        let inputNode = MockInputFormatProvider(formats: [invalidFormat, invalidFormat, validFormat])

        let resolvedFormat = try await bootstrapper.resolveInputFormat(
            for: inputNode,
            preferredSampleRate: 48_000
        )

        XCTAssertEqual(resolvedFormat.sampleRate, 48_000)
        XCTAssertEqual(inputNode.callCount, 3)
        let sleepCount = await sleepCounter.currentValue()
        XCTAssertEqual(sleepCount, 2)
    }
}

private final class MockInputFormatProvider: AudioInputFormatProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let formats: [AVAudioFormat]
    private(set) var callCount = 0

    init(formats: [AVAudioFormat]) {
        self.formats = formats
    }

    func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        lock.lock()
        defer { lock.unlock() }

        let index = min(callCount, formats.count - 1)
        callCount += 1
        return formats[index]
    }
}

private actor CallRecorder {
    private var calls: [String] = []

    func record(_ value: String) {
        calls.append(value)
    }

    func values() -> [String] {
        calls
    }
}

private actor Counter {
    var value: Int = 0

    func increment() {
        value += 1
    }

    func currentValue() -> Int {
        value
    }
}
