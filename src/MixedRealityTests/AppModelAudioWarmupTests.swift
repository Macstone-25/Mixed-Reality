import AVFoundation
import XCTest
@testable import MRCS

final class AppModelAudioWarmupTests: XCTestCase {
    @MainActor
    func testPrewarmAudioIfNeeded_OnlyRunsOnce() async throws {
        let bootstrapper = MockAudioBootstrapper()
        let appModel = AppModel(audioBootstrapper: bootstrapper)

        appModel.prewarmAudioIfNeeded()
        appModel.prewarmAudioIfNeeded()
        await waitForWarmupToFinish(appModel)
        let prewarmCallCount = await bootstrapper.prewarmCallCountValue()

        XCTAssertFalse(appModel.isAudioWarmupInProgress)
        XCTAssertNil(appModel.audioWarmupError)
        XCTAssertEqual(prewarmCallCount, 1)
    }

    @MainActor
    func testPrewarmAudioIfNeeded_SetsErrorOnFailure() async throws {
        let bootstrapper = MockAudioBootstrapper(shouldThrow: true)
        let appModel = AppModel(audioBootstrapper: bootstrapper)

        appModel.prewarmAudioIfNeeded()
        await waitForWarmupToFinish(appModel)
        let prewarmCallCount = await bootstrapper.prewarmCallCountValue()

        XCTAssertFalse(appModel.isAudioWarmupInProgress)
        XCTAssertNotNil(appModel.audioWarmupError)
        XCTAssertEqual(prewarmCallCount, 1)
    }

    @MainActor
    private func waitForWarmupToFinish(_ appModel: AppModel) async {
        for _ in 0..<100 {
            if !appModel.isAudioWarmupInProgress {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for audio warmup task to complete")
    }
}

private actor MockAudioBootstrapper: AudioSessionBootstrapping {
    private let shouldThrow: Bool
    private(set) var prewarmCallCount = 0

    init(shouldThrow: Bool = false) {
        self.shouldThrow = shouldThrow
    }

    func prewarm(preferredSampleRate: Double) async throws {
        prewarmCallCount += 1
        if shouldThrow {
            throw SpeechServiceError.runtimeError("forced failure")
        }
    }

    func prewarmCallCountValue() -> Int {
        prewarmCallCount
    }

    func resolveInputFormat(
        for inputNode: AudioInputFormatProviding,
        preferredSampleRate: Double
    ) async throws -> AVAudioFormat {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: preferredSampleRate,
            channels: 1
        ) else {
            throw SpeechServiceError.runtimeError("Failed to create test audio format")
        }
        return format
    }
}
