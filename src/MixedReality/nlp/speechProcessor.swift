import AVFoundation
import Starscream
import os

// MARK: - Deepgram response model

struct DeepgramResponse: Codable {
    let is_final: Bool?
    let speech_final: Bool?
    let channel: Channel?

    struct Channel: Codable {
        let alternatives: [Alternative]?
    }

    struct Alternative: Codable {
        let transcript: String?
        let words: [Word]?
    }

    struct Word: Codable {
        let word: String
        let speaker: Int?
        let start: Double?
        let end: Double?
    }
}

/// Lightweight envelope so we can ignore non-"Results" frames
private struct DeepgramEnvelope: Decodable {
    let type: String?
}

/*
  Inputs:
  - artifacts: The instance of the ArtifactCollector class
  - sampleRate: The audio sample rate in Hz (default: 48,000)
  - channels: Number of audio channels (default: 1)
  - interleaved: Whether audio data is interleaved (true/false, default: true)
*/
class SpeechProcessor: WebSocketDelegate {
    public private(set) var conversation: [String: [String]] = [:]
    private let logger = Logger(subsystem: "NLP", category: "SpeechProcessor")

    private let audioEngine = AVAudioEngine()
    private let converterNode = AVAudioMixerNode()
    private let sinkNode = AVAudioMixerNode()

    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let interleaved: Bool

    // Tune this (ms). Smaller -> finals arrive faster.
    private let endpointingMs: Int = 1500

    private lazy var outputFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: interleaved
        )!
    }()
    
    // Audio writing properties
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var isRecording = false
    private let artifacts: ArtifactCollector?
    private var eventsHandle: FileHandle?
    private let processingQueue = DispatchQueue(label: "com.speech.processor.write", qos: .userInitiated)

    // Deepgram properties
    private let deepgramKey: String

    private lazy var socket: Starscream.WebSocket = {
        let urlString =
            "wss://api.deepgram.com/v1/listen" +
            "?model=nova-2" +
            "&diarize=true" +
            "&punctuate=true" +
            "&filler_words=true" +
            "&encoding=linear16" +
            "&interim_results=true" +
            "&endpointing=\(endpointingMs)" +
            "&vad_events=true" +
            "&sample_rate=\(Int(sampleRate))" +
            "&channels=\(channels)"


        guard let url = URL(string: urlString) else {
            fatalError("Invalid WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")
        return Starscream.WebSocket(request: request)
    }()

    weak var delegate: SpeechProcessorDelegate?
    
    init(artifacts: ArtifactCollector? = nil, sampleRate: Double = 48000, channels: AVAudioChannelCount = 1, interleaved: Bool = true) {
        self.artifacts = artifacts
        self.sampleRate = sampleRate
        self.channels = channels
        self.interleaved = interleaved

        guard let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] else {
            fatalError("Deepgram API Key not found.")
        }
        self.deepgramKey = key

        socket.delegate = self
        configureAudioSession()
        socket.connect()
        
        artifacts?.logEvent(type: "INFO", message: "SpeechProcessor initialized with sampleRate: \(sampleRate)")
    }

    // Configure audio based on device. MacOS is only used for certain testing purposes.
    private func configureAudioSession() {
        #if os(macOS)
        // macOS: Use AVCaptureDevice to check for microphone permissions
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            self.prepareAudioGraphAfterSessionActivation()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.prepareAudioGraphAfterSessionActivation()
                    }
                } else {
                    self.logger.error("Microphone permission denied on macOS.")
                }
            }
        default:
            self.logger.error("Microphone permission denied or restricted on macOS.")
        }

        #else
        // visionOS / iOS: Use AVAudioSession
        let session = AVAudioSession.sharedInstance()

        session.requestRecordPermission { granted in
            if !granted {
                self.logger.error("Microphone permission denied.")
                return
            }
            DispatchQueue.main.async {
                do {
                    try session.setCategory(.playAndRecord, options: [.duckOthers, .allowBluetooth])
                    try session.setMode(.measurement)
                    try session.setActive(true, options: [])
                    
                    // On visionOS, once the session is active, we prepare the graph
                    self.prepareAudioGraphAfterSessionActivation()
                } catch {
                    self.logger.error("Failed to configure AVAudioSession: \(error.localizedDescription)")
                }
            }
        }
        #endif
    }
    
    private func configureAssetWriter(inputFormat: AVAudioFormat) {
        // If no artifacts collector, skip file writing entirely
        guard let artifacts = artifacts else {
            logger.info("No artifacts collector provided. File recording disabled.")
            return
        }
        
        let fileName = "conversation.m4a"
        
        do {
            let fileURL = try artifacts.getFileURL(name: fileName)
            assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .m4a)
            
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: inputFormat.channelCount,
                AVEncoderBitRateKey: 128000
            ]
            
            assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
            assetWriterInput?.expectsMediaDataInRealTime = true
            
            if let input = assetWriterInput, assetWriter!.canAdd(input) {
                assetWriter!.add(input)
            }
            
            isRecording = true
            artifacts.logEvent(type: "AUDIO", message: "AssetWriter configured at \(fileURL.lastPathComponent)")
        } catch {
            logger.error("AssetWriter setup failed: \(error.localizedDescription)")
            artifacts.logEvent(type: "ERROR", message: "AssetWriter failed: \(error.localizedDescription)")
        }
    }

    private func prepareAudioGraphAfterSessionActivation() {
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.inputFormat(forBus: 0)

        let channelCount = nativeFormat.channelCount
        let sr = nativeFormat.sampleRate
        guard channelCount > 0, sr > 0 else {
            logger.error("Invalid native input format — channels: \(channelCount), sampleRate: \(sr)")
            return
        }
        
        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)
        configureAssetWriter(inputFormat: nativeFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] buffer, time in
                    guard let self = self else { return }

                    self.processingQueue.async {
                        // Deepgram logic
                        if let pcmData = self.convertBufferToPCM16(buffer: buffer, targetChannelCount: 1) {
                            self.socket.write(data: pcmData)
                        }

                        // File writing logic
                        if self.isRecording,
                           let sampleBuffer = cmSampleBufferFromPCM(buffer),
                           let writer = self.assetWriter,
                           let input = self.assetWriterInput {
                            
                            if writer.status == .unknown {
                                let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                                if writer.startWriting() {
                                    writer.startSession(atSourceTime: startTime)
                                }
                            }

                            if writer.status == .writing && input.isReadyForMoreMediaData {
                                input.append(sampleBuffer)
                            }
                        }
                    }
                }

        audioEngine.connect(inputNode, to: converterNode, format: nativeFormat)
        audioEngine.connect(converterNode, to: sinkNode, format: nativeFormat)

        do {
            try audioEngine.start()
            logger.info("Audio engine started.")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
            
    // Convert Float32/Float64 buffer to PCM16 and downmix if needed
    private func convertBufferToPCM16(buffer: AVAudioPCMBuffer, targetChannelCount: AVAudioChannelCount) -> Data? {
        let format = buffer.format
        let frameLength = Int(buffer.frameLength)
        let channels = Int(format.channelCount)

        guard format.commonFormat == .pcmFormatFloat32,
            let floatChannelData = buffer.floatChannelData else {
            // Implement other conversions if needed
            return nil
        }
        
        var interleavedMono = [Int16]()
        interleavedMono.reserveCapacity(frameLength)
        
        // Simple downmix: average channels into mono
        for frameIndex in 0..<frameLength {
            var sampleSum: Float = 0.0
            for ch in 0..<channels {
                sampleSum += floatChannelData[ch][frameIndex]
            }
            let avg = sampleSum / Float(channels)
            let clipped = max(-1.0, min(1.0, avg))
            let intSample = Int16(clipped * Float(Int16.max))
            interleavedMono.append(intSample)
        }

        return interleavedMono.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
    }
            
    // Handles WebSocket events: connection, disconnection, incoming messages, and errors
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            logger.info("WebSocket connected with headers: \(headers, privacy: .public)")
        case .disconnected(let reason, let code):
            logger.info("WebSocket disconnected. Reason: \(reason, privacy: .public), code: \(code)")
        case .text(let text):
            if let data = text.data(using: .utf8) {
                processJSON(data: data)
            }
        case .error(let error):
            if let error = error {
                logger.error("WebSocket error: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.error("WebSocket error: unknown")
            }
        default:
            break
        }
    }
            
    // Parses Deepgram JSON and sends transcript chunks to delegate
    public func processJSON(data: Data) {
        // ✅ Ignore non-Results frames so we don't spam decode errors and lose context.
        if let envelope = try? JSONDecoder().decode(DeepgramEnvelope.self, from: data),
           let type = envelope.type,
           type != "Results" {
            return
        }

        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            guard let alternatives = response.channel?.alternatives else { return }

            let finalFlag = response.is_final ?? false

            for alt in alternatives {
                if let words = alt.words, !words.isEmpty {
                    var speakerSentences: [String: (text: String, start: Double?, end: Double?)] = [:]
                    
                    for wordInfo in words {
                        let speakerID = wordInfo.speaker.map { "spk_\($0)" } ?? "user"
                        
                        if var entry = speakerSentences[speakerID] {
                            entry.text += wordInfo.word + " "
                            entry.end = wordInfo.end
                            speakerSentences[speakerID] = entry
                        } else {
                            speakerSentences[speakerID] = (text: wordInfo.word + " ", start: wordInfo.start, end: wordInfo.end)
                        }
                    }
                    
                    for (speakerID, entry) in speakerSentences {
                        let trimmedText = entry.text.trimmingCharacters(in: .whitespaces)
                        guard !trimmedText.isEmpty else { continue }
                        conversation[speakerID, default: []].append(trimmedText)
                        
                        // Notify delegate – treat every sentence as final
                        let chunk = DeepgramTranscriptChunk(
                            speakerID: speakerID,
                            start_time: entry.start,
                            end_time: entry.end,
                            text: trimmedText,
                            isFinal: finalFlag
                        )
                        delegate?.speechProcessor(self, didReceiveChunk: chunk)
                        logger.info("Speaker: \(speakerID, privacy: .public), Sentence: \(trimmedText, privacy: .public)")
                    }
                    
                } else if let transcript = alt.transcript?.trimmingCharacters(in: .whitespaces),
                          !transcript.isEmpty {
                    let speakerID = "user"
                    conversation[speakerID, default: []].append(transcript)
                    
                    let chunk = DeepgramTranscriptChunk(
                        speakerID: speakerID,
                        start_time: nil,
                        end_time: nil,
                        text: transcript,
                        isFinal: finalFlag
                    )
                    delegate?.speechProcessor(self, didReceiveChunk: chunk)
                    logger.info("Speaker: \(speakerID, privacy: .public), Sentence: \(transcript, privacy: .public)")
                }
            }
        } catch {
            artifacts?.logEvent(type: "ERROR", message: "JSON Decoding failed")
            logger.error("Failed to decode Deepgram JSON: \(error.localizedDescription, privacy: .public)")
        }
    }
            
    private func cleanupEngine() {
        conversation.removeAll()
        
        // Reset engine to clear the internal graph connections
        audioEngine.reset()
        
        socket.disconnect(closeCode: 1000)
        socket.delegate = nil
        logger.info("Audio engine and WebSocket fully deconfigured.")
    }
            
    // Cleans up audio engine and WebSocket, stopping all streaming activity
    public func deconfigureAudioEngine(completion: @escaping () -> Void = {}) {
        isRecording = false
        artifacts?.logEvent(type: "INFO", message: "Deconfiguring Audio Engine...")

        audioEngine.inputNode.removeTap(onBus: 0)

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        guard let writer = assetWriter,
              let writerInput = assetWriterInput else {
            cleanupEngine()
            completion()
            return
        }

        if writer.status == .writing {
            writerInput.markAsFinished()
            writer.finishWriting { [weak self] in
                guard let self = self else { return }

                if let error = self.assetWriter?.error {
                    logger.error("Writer Error: \(error.localizedDescription)")
                } else {
                    logger.info("File finalized successfully.")
                }

                cleanupEngine()
                completion()
            }
        } else {
            // Writer never started, nothing to finish
            cleanupEngine()
            completion()
        }
    }
}
