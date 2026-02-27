import AVFoundation
import Foundation

protocol AudioSessionBootstrapping {
    func prewarm(preferredSampleRate: Double) async throws
    func resolveInputFormat(
        for inputNode: AudioInputFormatProviding,
        preferredSampleRate: Double
    ) async throws -> AVAudioFormat
}

protocol AudioInputFormatProviding {
    func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat
}

extension AVAudioInputNode: AudioInputFormatProviding {}

actor AudioSessionBootstrapper: AudioSessionBootstrapping {
    static let shared = AudioSessionBootstrapper()

    private let permissionRequester: @Sendable () async -> Bool
    private let sessionConfigurator: @Sendable (Double) async throws -> Void
    private let sleepFn: @Sendable (UInt64) async -> Void
    private let maxFormatResolutionAttempts: Int
    private let formatRetryDelayNanoseconds: UInt64

    private var isConfigured = false
    private var warmupTask: Task<Void, Error>?

    init(
        permissionRequester: @escaping @Sendable () async -> Bool = {
            await AVAudioApplication.requestRecordPermission()
        },
        sessionConfigurator: @escaping @Sendable (Double) async throws -> Void = { preferredSampleRate in
            try await MainActor.run {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(
                    .playAndRecord,
                    mode: .measurement,
                    options: [.allowBluetoothA2DP, .defaultToSpeaker]
                )
                try session.setPreferredSampleRate(preferredSampleRate)
                try session.setPreferredIOBufferDuration(0.005) // 5 ms
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            }
        },
        sleepFn: @escaping @Sendable (UInt64) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        },
        maxFormatResolutionAttempts: Int = 3,
        formatRetryDelayNanoseconds: UInt64 = 50_000_000
    ) {
        self.permissionRequester = permissionRequester
        self.sessionConfigurator = sessionConfigurator
        self.sleepFn = sleepFn
        self.maxFormatResolutionAttempts = max(1, maxFormatResolutionAttempts)
        self.formatRetryDelayNanoseconds = formatRetryDelayNanoseconds
    }

    func prewarm(preferredSampleRate: Double) async throws {
        if isConfigured { return }
        if let warmupTask { return try await warmupTask.value }

        let permissionRequester = self.permissionRequester
        let sessionConfigurator = self.sessionConfigurator

        let task = Task { [permissionRequester, sessionConfigurator] in
            let isPermissionGranted = await permissionRequester()
            guard isPermissionGranted else {
                throw SpeechServiceError.permissionError("Recording permission was not granted")
            }

            try await sessionConfigurator(preferredSampleRate)
        }
        warmupTask = task

        do {
            try await task.value
            isConfigured = true
            warmupTask = nil
        } catch {
            warmupTask = nil
            throw error
        }
    }

    func resolveInputFormat(
        for inputNode: AudioInputFormatProviding,
        preferredSampleRate: Double
    ) async throws -> AVAudioFormat {
        try await prewarm(preferredSampleRate: preferredSampleRate)

        var lastChannelCount: AVAudioChannelCount = 0
        var lastSampleRate: Double = 0

        for attempt in 1...maxFormatResolutionAttempts {
            let format = await MainActor.run {
                inputNode.outputFormat(forBus: 0)
            }
            lastChannelCount = format.channelCount
            lastSampleRate = format.sampleRate

            if format.channelCount > 0 && format.sampleRate > 0 {
                return format
            }

            if attempt < maxFormatResolutionAttempts {
                await sleepFn(formatRetryDelayNanoseconds)
            }
        }

        throw SpeechServiceError.runtimeError(
            "Invalid input format — channels: \(lastChannelCount), sample rate: \(lastSampleRate)"
        )
    }
}
