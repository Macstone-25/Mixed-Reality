//
//  LiveAudioCapture.swift
//  MixedReality
//

import AVFoundation

final class LiveAudioCapture: AudioCapture {

    private let audioEngine = AVAudioEngine()
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?

    var inputFormat: AVAudioFormat {
        audioEngine.inputNode.inputFormat(forBus: 0)
    }

    var isEngineRunning: Bool {
        audioEngine.isRunning
    }

    var recordingError: Error? {
        assetWriter?.error
    }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.allowBluetoothA2DP, .defaultToSpeaker]
        )
        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func deactivateSession() throws {
        try AVAudioSession.sharedInstance().setActive(false)
    }

    func installTap(
        bufferSize: AVAudioFrameCount,
        handler: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void
    ) throws {
        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: inputFormat,
            block: handler
        )
    }

    func removeTap() {
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    func startEngine() throws {
        try audioEngine.start()
    }

    func stopEngine() {
        audioEngine.stop()
    }

    func resetEngine() {
        audioEngine.reset()
    }

    func startRecording(to url: URL) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)

        let sr = inputFormat.sampleRate
        let safeSampleRate: Double = (sr == 44_100 || sr == 48_000) ? sr : 48_000

        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: safeSampleRate,
            AVNumberOfChannelsKey: min(Int(inputFormat.channelCount), 2),
            AVEncoderBitRateKey: 128_000
        ])

        input.expectsMediaDataInRealTime = true

        if writer.canAdd(input) {
            writer.add(input)
        }

        self.assetWriter = writer
        self.assetWriterInput = input
    }

    func stopRecording() async {
        await assetWriter?.finishWriting()
    }

    /// Called from processAudioBuffer — appends encoded audio to disk
    func append(_ sampleBuffer: CMSampleBuffer) {
        guard let writer = assetWriter,
              let input = assetWriterInput else { return }

        if writer.status == .unknown {
            let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if writer.startWriting() {
                writer.startSession(atSourceTime: startTime)
            }
        }

        if writer.status == .writing, input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }
}
