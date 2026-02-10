//
//  SpeechService.swift
//  MixedReality
//

import Foundation
import Combine
import Starscream
import AVFoundation
import OSLog
import os

/// Standard message envelope indicating the message type (e.g. Results, SpeechStarted, ...)
private struct DeepgramEnvelope: Codable {
    let type: String?
}

/// Deepgram Results format
private struct DeepgramResults: Codable {
    let is_final: Bool
    let channel: Channel

    struct Channel: Codable {
        let alternatives: [Alternative]
    }

    struct Alternative: Codable {
        let transcript: String
        let words: [Word]
    }

    struct Word: Codable {
        let word: String
        let punctuated_word: String?
        let speaker: Int?
        let start: Double
        let end: Double
    }
}

enum SpeechServiceError: Error {
    case configError(String)
    case apiError(String)
    case runtimeError(String)
    case permissionError(String)
}

enum AudioAnonymizationPolicy {
    case none
    case pitchShift(semitones: Float, deleteOriginal: Bool)
}

class SpeechService: WebSocketDelegate {
    private let logger = Logger(subsystem: "SpeechService", category: "Services")
    
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let config: DeepgramConfig
    private let anonymizationPolicy: AudioAnonymizationPolicy
    
    /// Fired any time a transcript chunk is received from Deepgram
    let transcriptChunkEvent = PassthroughSubject<TranscriptChunk, Never>()
    
    private var socket: Starscream.WebSocket
    private var keepAliveTimer: Timer?
    private var isConnected = false
    
    private let audioEngine = AVAudioEngine()
    private let audioFormat: AVAudioFormat
    
    private let assetWriter: AVAssetWriter
    private let assetWriterInput: AVAssetWriterInput
    private let conversationFileURL: URL
    
    private let jsonDecoder = JSONDecoder()
    
    init(
        artifacts: ArtifactService,
        experiment: ExperimentModel,
        config: DeepgramConfig,
        anonymizationPolicy: AudioAnonymizationPolicy
    ) async throws {
        self.artifacts = artifacts
        self.experiment = experiment
        self.config = config
        self.anonymizationPolicy = anonymizationPolicy
        
        /// Configure audio session
        let isPermissionGranted = await AVAudioApplication.requestRecordPermission()
        guard isPermissionGranted else {
            throw SpeechServiceError.permissionError("Recording permission was not granted")
        }
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.allowBluetoothA2DP, .defaultToSpeaker]
        )
        
        try session.setPreferredSampleRate(config.preferredSampleRate)
        try session.setPreferredIOBufferDuration(0.005) // 5 ms
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        /// Create AssetWriter
        let fileURL = try await artifacts.getFileURL(name: "Conversation.m4a")
        self.conversationFileURL = fileURL
        
        assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .m4a)
        
        audioFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        guard audioFormat.channelCount > 0, audioFormat.sampleRate > 0 else {
            throw SpeechServiceError.runtimeError(
                "Invalid input format — channels: \(audioFormat.channelCount), sample rate: \(audioFormat.sampleRate)"
            )
        }
        
        assetWriterInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: audioFormat.sampleRate,
                AVNumberOfChannelsKey: audioFormat.channelCount,
                AVEncoderBitRateKey: 128000
            ]
        )
        
        if assetWriter.canAdd(assetWriterInput) {
            assetWriterInput.expectsMediaDataInRealTime = true
            assetWriter.add(assetWriterInput)
        }
        
        /// Construct Deepgram WebSocket URL with audio and transcription parameters
        var urlComponents = URLComponents()
        urlComponents.scheme = "wss"
        urlComponents.host = "api.deepgram.com"
        urlComponents.path = "/v1/listen"
        urlComponents.queryItems = [
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(Int(audioFormat.sampleRate))),
            URLQueryItem(name: "model", value: config.model),
            URLQueryItem(name: "language", value: config.language),
            URLQueryItem(name: "channels", value: String(config.channels)),
            URLQueryItem(name: "endpointing", value: String(config.endpointingMs)),
            URLQueryItem(name: "diarize", value: config.diarize ? "true" : "false"),
            URLQueryItem(name: "punctuate", value: config.punctuate ? "true" : "false"),
            URLQueryItem(name: "filler_words", value: config.fillerWords ? "true" : "false"),
            URLQueryItem(name: "interim_results", value: config.interimResults ? "true" : "false"),
            URLQueryItem(name: "vad_events", value: config.vadEvents ? "true" : "false")
        ]
        
        guard let url = urlComponents.url else {
            throw SpeechServiceError.configError("Invalid WebSocket URL")
        }
        
        guard let deepgramKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] else {
            throw SpeechServiceError.apiError("DEEPGRAM_API_KEY not set")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")
        
        socket = Starscream.WebSocket(request: request)
        socket.delegate = self
    }
    
    /// Connects to Deepgram and begins streaming audio
    func connect() async throws {
        guard !isConnected else {
            throw SpeechServiceError.runtimeError("Already connected")
        }
        
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        
        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: audioFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer: buffer, time: time)
        }
        
        try audioEngine.start()
        
        await artifacts.logEvent(
            type: "SpeechService",
            message: "Connecting to \(socket.request.url?.absoluteString ?? "nil")"
        )
        
        socket.connect()
        isConnected = true
        
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true
        ) { [weak self] _ in
            self?.sendKeepAlive()
        }
    }
    
    /// Disconnect from Deepgram WebSocket and deactivate microphone
    func disconnect() async {
        guard isConnected else {
            logger.error("Already disconnected")
            return
        }
        
        logger.info("🔌 Disconnecting SpeechService...")
        isConnected = false
        
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.reset()
        try? AVAudioSession.sharedInstance().setActive(false)
        
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        
        socket.disconnect(closeCode: 1000)
        
        await assetWriter.finishWriting()
        
        if let error = assetWriter.error {
            await artifacts.logEvent(
                type: "SpeechService",
                message: "AssetWriter error: \(error.localizedDescription)"
            )
        } else {
            await artifacts.logEvent(
                type: "SpeechService",
                message: "Audio recording saved to \(conversationFileURL.lastPathComponent)"
            )
            
            switch anonymizationPolicy {
            case .none:
                await artifacts.logEvent(
                    type: "SpeechService",
                    message: "Audio anonymization disabled"
                )
                
            case .pitchShift(let semitones, let deleteOriginal):
                do {
                    let anonymizedURL = try anonymizeConversationAudio(
                        pitchSemitones: semitones,
                        deleteOriginal: deleteOriginal
                    )
                    
                    await artifacts.logEvent(
                        type: "SpeechService",
                        message: "Anonymized audio created: \(anonymizedURL.lastPathComponent)"
                    )
                } catch {
                    await artifacts.logEvent(
                        type: "SpeechService",
                        message: "Audio anonymization failed: \(error.localizedDescription)"
                    )
                }
            }
        }
        
        logger.info("🛑 SpeechService stopped")
    }
    
    /// Starscream WebSocket delegate method for handling connection, messages, and errors
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        Task {
            switch event {
            case .connected:
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket connected")
            case .peerClosed:
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket closed")
            case .cancelled:
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket cancelled")
            case .disconnected(let reason, let code):
                await artifacts.logEvent(
                    type: "Deepgram",
                    message: "WebSocket disconnected (\(code)): \(reason)"
                )
            case .text(let text):
                if let data = text.data(using: .utf8) {
                    do {
                        try await processJSON(data: data)
                    } catch {
                        await artifacts.logEvent(
                            type: "Deepgram",
                            message: "Failed to parse Deepgram response: \(error.localizedDescription)"
                        )
                    }
                }
            case .error(let error):
                await artifacts.logEvent(
                    type: "Deepgram",
                    message: "WebSocket error: \(error?.localizedDescription ?? "unknown")"
                )
            default:
                await artifacts.logEvent(
                    type: "Deepgram",
                    message: "Unhandled WebSocketEvent: \(String(describing: event))"
                )
            }
        }
    }
    
    private func sendKeepAlive() {
        let keepAlive: [String: Any] = ["type": "KeepAlive"]
        do {
            let data = try JSONSerialization.data(withJSONObject: keepAlive, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                socket.write(string: jsonString)
            } else {
                logger.warning("Failed to convert data to UTF-8 string: \(data)")
            }
        } catch {
            logger.warning("Failed to encode KeepAlive message: \(error)")
        }
    }
    
    /// Performs format conversions and sends audio data to the WebSocket and AssetWriter
    private func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isConnected else { return }
        
        /// Send audio buffer to Deepgram via WebSocket (in PCM16 format)
        if let pcmData = AudioBufferUtils.convertBufferToPCM16(
            buffer: buffer,
            targetChannelCount: config.channels
        ) {
            socket.write(data: pcmData)
        }
        
        /// Send audio buffer to asset writer (in native format)
        if let sampleBuffer = AudioBufferUtils.cmSampleBufferFromPCM(buffer) {
            if assetWriter.status == .unknown {
                let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                if assetWriter.startWriting() {
                    assetWriter.startSession(atSourceTime: startTime)
                }
            }
            
            if assetWriter.status == .writing,
               assetWriterInput.isReadyForMoreMediaData {
                assetWriterInput.append(sampleBuffer)
            }
        }
    }
    
    /// Parses JSON data into TranscriptChunk events
    private func processJSON(data: Data) async throws {
        /// We are only interested in Results data frames, the rest can be ignored
        let envelope = try jsonDecoder.decode(DeepgramEnvelope.self, from: data)
        guard envelope.type == "Results" else { return }
        
        let results = try jsonDecoder.decode(DeepgramResults.self, from: data)
        
        /// We can only handle one interpretation, so we take the most likely option and ignore other alternatives
        /// If this result was empty (i.e. there are no words), we simply ignore it and continue
        guard let words = results.channel.alternatives.first?.words,
              !words.isEmpty else { return }
        
        // Assemble full diarized sentences from individually diarized words
        var speakerSentences: [String: (text: String, start: Double, end: Double)] = [:]
        
        for wordInfo in words {
            let speakerID = wordInfo.speaker.map { "Speaker:\($0)" } ?? "Speaker:Unknown"
            let word = wordInfo.punctuated_word ?? wordInfo.word
            
            if var entry = speakerSentences[speakerID] {
                entry.text += " " + word
                entry.end = wordInfo.end
                speakerSentences[speakerID] = entry
            } else {
                speakerSentences[speakerID] = (
                    text: word,
                    start: wordInfo.start,
                    end: wordInfo.end
                )
            }
        }
        
        for (speakerID, entry) in speakerSentences {
            let trimmedText = entry.text.trimmingCharacters(in: .whitespaces)
            guard !trimmedText.isEmpty else { continue }
            
            let chunk = TranscriptChunk(
                text: trimmedText,
                speakerID: speakerID,
                isFinal: results.is_final,
                startAt: entry.start,
                endAt: entry.end
            )
            
            let timeRange = String(
                format: "(%.1fs - %.1fs)",
                chunk.startAt,
                chunk.endAt
            )
            
            let logMessage = "\(timeRange) \(chunk)"
            
            if chunk.isFinal {
                logger.info("✅ \(logMessage)")
                await artifacts.logEvent(type: "Transcript", message: logMessage)
            } else {
                logger.info("❓ \(logMessage)")
            }
            
            transcriptChunkEvent.send(chunk)
        }
    }
    
    private func anonymizeConversationAudio(
        outputName: String = "conversation_anonymized.m4a",
        pitchSemitones: Float,
        deleteOriginal: Bool
    ) async throws -> URL {

        let inputURL = conversationFileURL
        let outputURL = try await artifacts.getFileURL(name: outputName)

        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()

        pitch.pitch = pitchSemitones * 100 // cents

        engine.attach(player)
        engine.attach(pitch)
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: engine.mainMixerNode, format: format)

        try engine.enableManualRenderingMode(
            .offline,
            format: format,
            maximumFrameCount: 4096
        )

        try engine.start()

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: inputFile.fileFormat.settings
        )

        await player.scheduleFile(inputFile, at: nil)
        player.play()

        let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        )!

        while engine.manualRenderingSampleTime < inputFile.length {
            let status = try engine.renderOffline(
                buffer.frameCapacity,
                to: buffer
            )

            if status == .success {
                try outputFile.write(from: buffer)
            }
        }

        engine.stop()
        engine.reset()

        if deleteOriginal {
            try? FileManager.default.removeItem(at: inputURL)
            logger.info("Deleted original conversation audio after anonymization")
        }

        logger.info("Anonymized audio written to \(outputURL.lastPathComponent)")
        return outputURL
    }

}
