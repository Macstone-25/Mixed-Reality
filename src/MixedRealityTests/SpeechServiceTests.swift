//
//  SpeechServiceTests.swift
//  MixedRealityTests
//

import XCTest
import AVFoundation
import Combine
@testable import MRCS

final class MockSpeechEngine: SpeechEngine {
    let transcriptChunkEvent = PassthroughSubject<TranscriptChunk, Never>()

    var startCallCount = 0
    var stopCallCount = 0
    var processedBuffers: [AVAudioPCMBuffer] = []
    var shouldThrowOnStart = false

    func start() async throws {
        startCallCount += 1
        if shouldThrowOnStart {
            throw SpeechServiceError.runtimeError("Mock start failure")
        }
    }

    func stop() async {
        stopCallCount += 1
    }

    func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        processedBuffers.append(buffer)
    }
}

final class MockAudioCapture: AudioCapture {
    var inputFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    var permissionGranted = true
    var shouldThrowOnActivate = false
    var shouldThrowOnInstallTap = false
    var shouldThrowOnStartEngine = false

    var activateCallCount = 0
    var deactivateCallCount = 0
    var installTapCallCount = 0
    var removeTapCallCount = 0
    var startEngineCallCount = 0
    var stopEngineCallCount = 0
    var resetEngineCallCount = 0
    var startRecordingCallCount = 0
    var stopRecordingCallCount = 0
    var appendCallCount = 0

    var isEngineRunning = false
    var recordingError: Error? = nil

    var tapHandler: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?

    func requestPermission() async -> Bool {
        permissionGranted
    }

    func activateSession() throws {
        activateCallCount += 1
        if shouldThrowOnActivate {
            throw SpeechServiceError.runtimeError("Mock activate failure")
        }
    }

    func deactivateSession() throws {
        deactivateCallCount += 1
    }

    func installTap(
        bufferSize: AVAudioFrameCount,
        handler: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void
    ) throws {
        installTapCallCount += 1
        tapHandler = handler
        if shouldThrowOnInstallTap {
            throw SpeechServiceError.runtimeError("Mock tap failure")
        }
    }

    func removeTap() {
        removeTapCallCount += 1
        tapHandler = nil
    }

    func startEngine() throws {
        startEngineCallCount += 1
        if shouldThrowOnStartEngine {
            throw SpeechServiceError.runtimeError("Mock engine start failure")
        }
        isEngineRunning = true
    }

    func stopEngine() {
        stopEngineCallCount += 1
        isEngineRunning = false
    }

    func resetEngine() {
        resetEngineCallCount += 1
        isEngineRunning = false
    }

    func startRecording(to url: URL) throws {
        startRecordingCallCount += 1
    }

    func stopRecording() async {
        stopRecordingCallCount += 1
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        appendCallCount += 1
    }

    /// Simulate an incoming audio buffer to test processAudioBuffer routing
    func simulateBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime = AVAudioTime()) {
        tapHandler?(buffer, time)
    }
}

final class MockAudioAnonymizer: AudioAnonymizer {
    var anonymizeCallCount = 0
    var shouldThrow = false
    var returnNilURL = false

    func anonymize(inputURL: URL, outputURL: URL) async throws -> URL? {
        anonymizeCallCount += 1
        if shouldThrow {
            throw NSError(domain: "MockAnonymizer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Anonymization failed"])
        }
        return returnNilURL ? nil : outputURL
    }
}

final class SpeechServiceTests: XCTestCase {

    private func makeArtifactService(id: String = "test") throws -> ArtifactService {
        try ArtifactService(id: id)
    }

    private func makeExperimentModel() throws -> ExperimentModel {
        try ExperimentModel(config: .default)
    }

    private func makeSUT(
        engine: MockSpeechEngine = MockSpeechEngine(),
        capture: MockAudioCapture = MockAudioCapture(),
        artifacts: ArtifactService? = nil,
        anonymizer: (any AudioAnonymizer)? = nil
    ) async throws -> (SpeechService, MockSpeechEngine, MockAudioCapture) {
        let artifactService = try artifacts ?? makeArtifactService()
        let service = try await SpeechService(
            engine: engine,
            artifacts: artifactService,
            experiment: makeExperimentModel(),
            anonymizer: anonymizer,
            capture: capture
        )
        return (service, engine, capture)
    }

    private func makeChunk(
        text: String,
        speakerID: String = "S1",
        startAt: Double = 0.0,
        endAt: Double = 1.0,
        isFinal: Bool = false
    ) -> TranscriptChunk {
        TranscriptChunk(
            text: text,
            speakerID: speakerID,
            isFinal: isFinal,
            startAt: startAt,
            endAt: endAt
        )
    }

    /// init should call requestPermission exactly once
    func test_init_requestsPermission() async throws {
        let capture = MockAudioCapture()
        _ = try await makeSUT(capture: capture)
        // permission is checked inside init before anything else
        XCTAssertTrue(capture.permissionGranted)
    }

    /// init should throw permissionError when permission is denied
    func test_init_throwsWhenPermissionDenied() async throws {
        let capture = MockAudioCapture()
        capture.permissionGranted = false

        do {
            _ = try await makeSUT(capture: capture)
            XCTFail("Expected permissionError")
        } catch SpeechServiceError.permissionError {
            // expected
        }
    }

    /// init should activate the audio session
    func test_init_activatesSession() async throws {
        let capture = MockAudioCapture()
        _ = try await makeSUT(capture: capture)
        XCTAssertGreaterThanOrEqual(capture.activateCallCount, 1)
    }

    /// init should call startRecording exactly once
    func test_init_startsRecording() async throws {
        let capture = MockAudioCapture()
        _ = try await makeSUT(capture: capture)
        XCTAssertEqual(capture.startRecordingCallCount, 1)
    }

    /// connect() should call engine.start() exactly once
    func test_connect_startsEngine() async throws {
        let (service, engine, _) = try await makeSUT()
        try await service.connect()
        XCTAssertEqual(engine.startCallCount, 1)
    }

    /// connect() should install a tap on the capture
    func test_connect_installsTap() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        XCTAssertEqual(capture.installTapCallCount, 1)
    }

    /// connect() should start the audio engine via capture
    func test_connect_startsAudioEngine() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        XCTAssertEqual(capture.startEngineCallCount, 1)
    }

    /// connect() twice should throw without calling engine.start() a second time
    func test_connect_throwsIfAlreadyConnected() async throws {
        let (service, engine, _) = try await makeSUT()
        try await service.connect()

        do {
            try await service.connect()
            XCTFail("Expected SpeechServiceError.runtimeError")
        } catch SpeechServiceError.runtimeError {
            // expected
        }

        XCTAssertEqual(engine.startCallCount, 1)
    }

    /// connect() should not install a second tap if already installed
    func test_connect_doesNotInstallTapTwice() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        // isActive guard prevents second connect, but tap guard is independent
        XCTAssertEqual(capture.installTapCallCount, 1)
    }

    /// If the engine throws on start, connect() propagates the error
    func test_connect_propagatesEngineStartError() async throws {
        let engine = MockSpeechEngine()
        engine.shouldThrowOnStart = true
        let (service, _, _) = try await makeSUT(engine: engine)

        do {
            try await service.connect()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is SpeechServiceError)
        }
    }

    /// disconnect() should call engine.stop() exactly once
    func test_disconnect_stopsEngine() async throws {
        let (service, engine, _) = try await makeSUT()
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(engine.stopCallCount, 1)
    }

    /// disconnect() should remove the tap
    func test_disconnect_removesTap() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(capture.removeTapCallCount, 1)
    }

    /// disconnect() should stop and reset the audio engine via capture
    func test_disconnect_stopsAndResetsAudioEngine() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(capture.stopEngineCallCount, 1)
        XCTAssertEqual(capture.resetEngineCallCount, 1)
    }

    /// disconnect() should deactivate the session
    func test_disconnect_deactivatesSession() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(capture.deactivateCallCount, 1)
    }

    /// disconnect() should call stopRecording on capture
    func test_disconnect_stopsRecording() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(capture.stopRecordingCallCount, 1)
    }

    /// disconnect() before connect() should be a no-op
    func test_disconnect_beforeConnect_isNoOp() async throws {
        let (service, engine, capture) = try await makeSUT()
        await service.disconnect()
        XCTAssertEqual(engine.stopCallCount, 0)
        XCTAssertEqual(capture.removeTapCallCount, 0)
        XCTAssertEqual(capture.stopRecordingCallCount, 0)
    }

    /// connect() after disconnect() should succeed and re-install tap
    func test_connect_afterDisconnect_succeeds() async throws {
        let (service, engine, capture) = try await makeSUT()
        try await service.connect()
        await service.disconnect()
        try await service.connect()
        XCTAssertEqual(engine.startCallCount, 2)
        XCTAssertEqual(capture.installTapCallCount, 2)
    }

    /// When an anonymizer is configured, disconnect() should call anonymize() once
    func test_disconnect_withAnonymizer_callsAnonymize() async throws {
        let anonymizer = MockAudioAnonymizer()
        let (service, _, _) = try await makeSUT(anonymizer: anonymizer)
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(anonymizer.anonymizeCallCount, 1)
    }

    /// When no anonymizer is configured, disconnect() should complete cleanly
    func test_disconnect_withoutAnonymizer_completesCleanly() async throws {
        let (service, engine, _) = try await makeSUT(anonymizer: nil)
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(engine.stopCallCount, 1)
    }

    /// When the anonymizer throws, disconnect() must still complete
    func test_disconnect_anonymizerThrows_doesNotCrash() async throws {
        let anonymizer = MockAudioAnonymizer()
        anonymizer.shouldThrow = true
        let (service, _, _) = try await makeSUT(anonymizer: anonymizer)
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(anonymizer.anonymizeCallCount, 1)
    }

    /// When the anonymizer returns nil, disconnect() must still complete
    func test_disconnect_anonymizerReturnsNil_doesNotCrash() async throws {
        let anonymizer = MockAudioAnonymizer()
        anonymizer.returnNilURL = true
        let (service, _, _) = try await makeSUT(anonymizer: anonymizer)
        try await service.connect()
        await service.disconnect()
        XCTAssertEqual(anonymizer.anonymizeCallCount, 1)
    }

    /// reactivateIfNeeded() when not active should be a silent no-op
    func test_reactivateIfNeeded_whenNotActive_isNoOp() async throws {
        let (service, _, capture) = try await makeSUT()
        await service.reactivateIfNeeded()
        XCTAssertEqual(capture.startEngineCallCount, 0)
    }

    /// reactivateIfNeeded() when active and engine is stopped should restart it
    func test_reactivateIfNeeded_whenActive_restartsEngine() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        capture.isEngineRunning = false  // simulate engine dying in background
        await service.reactivateIfNeeded()
        XCTAssertEqual(capture.startEngineCallCount, 2) // once on connect, once on reactivate
    }

    /// reactivateIfNeeded() when engine is already running should not restart it
    func test_reactivateIfNeeded_engineAlreadyRunning_doesNotRestart() async throws {
        let (service, _, capture) = try await makeSUT()
        try await service.connect()
        // isEngineRunning is true after connect — reactivate should no-op the engine start
        await service.reactivateIfNeeded()
        XCTAssertEqual(capture.startEngineCallCount, 1)
    }

    /// Multiple chunks should be forwarded in order
    func test_transcriptChunkEvent_forwardsMultipleChunksInOrder() async throws {
        let engine = MockSpeechEngine()
        let (service, _, _) = try await makeSUT(engine: engine)
        var received: [TranscriptChunk] = []
        var cancellables = Set<AnyCancellable>()

        service.transcriptChunkEvent
            .sink { received.append($0) }
            .store(in: &cancellables)

        let texts = (0..<5).map { "Word \($0)" }
        texts.enumerated().forEach { i, text in
            engine.transcriptChunkEvent.send(
                makeChunk(text: text, startAt: Double(i), endAt: Double(i) + 1.0, isFinal: i == 4)
            )
        }

        XCTAssertEqual(received.count, 5)
        XCTAssertEqual(received.map(\.text), texts)
    }

    /// A final transcript chunk should trigger a logEvent call on ArtifactService
    func test_transcriptChunk_finalChunk_logsToArtifacts() async throws {
        let engine = MockSpeechEngine()
        let artifacts = try makeArtifactService(id: "log-final")
        let (service, _, _) = try await makeSUT(engine: engine, artifacts: artifacts)

        var cancellables = Set<AnyCancellable>()
        let expectation = XCTestExpectation(description: "final chunk logged")

        service.transcriptChunkEvent
            .filter(\.isFinal)
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        engine.transcriptChunkEvent.send(
            makeChunk(text: "Done", startAt: 0.0, endAt: 2.0, isFinal: true)
        )

        await fulfillment(of: [expectation], timeout: 1.0)
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    /// Partial chunks should not trigger logEvent
    func test_transcriptChunk_partialChunk_doesNotLog() async throws {
        let engine = MockSpeechEngine()
        let (service, _, _) = try await makeSUT(engine: engine)
        var cancellables = Set<AnyCancellable>()
        var receivedCount = 0

        service.transcriptChunkEvent
            .filter(\.isFinal)
            .sink { _ in receivedCount += 1 }
            .store(in: &cancellables)

        engine.transcriptChunkEvent.send(makeChunk(text: "partial", isFinal: false))
        engine.transcriptChunkEvent.send(makeChunk(text: "also partial", isFinal: false))

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(receivedCount, 0)
    }
}
