import AVFoundation
import Starscream
import os

// Formatting for the Deepgram response
struct DeepgramResponse: Codable {
    // NOTE: We don't rely on isFinal anymore; timing is handled on our side.
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

/*
  Handles audio format conversion, WebSocket lifecycle, and streaming.

  Inputs:
  - sampleRate: The audio sample rate in Hz (default: 48,000)
  - channels: Number of audio channels (default: 1)
  - interleaved: Whether audio data is interleaved (true/false, default: true)
*/
class SpeechProcessor: WebSocketDelegate {
    // Keeps a running record of all transcripts per speaker
    public private(set) var conversation: [String: [String]] = [:]
    // Logger setup
    private let logger = Logger(subsystem: "NLP", category: "SpeechProcessor")
    // Audio properties
    private let audioEngine = AVAudioEngine()
    private let converterNode = AVAudioMixerNode()
    private let sinkNode = AVAudioMixerNode()
    
    // Audio format properties
    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let interleaved: Bool
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
    private let artifacts: ArtifactCollector
    private var eventsHandle: FileHandle?
    private let processingQueue = DispatchQueue(label: "com.speech.processor.write", qos: .userInitiated)

    // Deepgram properties
    private let deepgramKey: String
    private lazy var socket: Starscream.WebSocket = {
        // Build URL dynamically based on audio format
        let urlString =
            "wss://api.deepgram.com/v1/listen" +
            "?model=nova-2" +
            "&diarize=true" +
            "&punctuate=true" +
            "&filler_words=true" +                      // <-- keep filler words like "um", "uh"
            "&encoding=linear16" +
            "&sample_rate=\(Int(sampleRate))" +
            "&channels=\(channels)"


        guard let url = URL(string: urlString) else {
            fatalError("Invalid WebSocket URL")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")
        return Starscream.WebSocket(request: urlRequest)
    }()
    
    // Delegate property
    weak var delegate: SpeechProcessorDelegate?
    
    init(artifacts: ArtifactCollector, sampleRate: Double = 48000, channels: AVAudioChannelCount = 1, interleaved: Bool = true) {
        self.artifacts = artifacts
        self.sampleRate = sampleRate
        self.channels = channels
        self.interleaved = interleaved
        // Load Deepgram API key from environment variables
        if let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] {
            self.deepgramKey = key
        } else {
            fatalError("Deepgram API Key not found.")
        }
        
        socket.delegate = self // Allow SpeechProcessor to receive WebSocket information
        configureAudioSession()
        socket.connect()
        
        artifacts.logEvent(type: "INFO", message: "SpeechProcessor initialized with sampleRate: \(sampleRate)")
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
                    try session.setCategory(.playAndRecord,
                                            options: [.duckOthers, .allowBluetooth])
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
        let timestamp = getTimestamp()
        let fileName = "conversation_\(timestamp).m4a"
        
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

        guard nativeFormat.channelCount > 0, nativeFormat.sampleRate > 0 else {
            logger.error("Invalid native input format.")
            return
        }
        
        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)
        configureAssetWriter(inputFormat: nativeFormat)

        // TAP ON INPUT NODE INSTEAD OF CONVERTER
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] buffer, time in
            guard let self = self, self.isRecording else { return }

            // Offload ALL processing to the background queue
            self.processingQueue.async {
                // 1. Handle WebSocket
                if let pcmData = self.convertBufferToPCM16(buffer: buffer, targetChannelCount: 1) {
                    self.socket.write(data: pcmData)
                }

                // 2. Handle File Writing
                guard let sampleBuffer = cmSampleBufferFromPCM(buffer),
                      let writer = self.assetWriter,
                      let input = self.assetWriterInput else { return }

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

        // If format is already Int16 (rare), handle differently — typical is .pcmFormatFloat32
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
            // clamp and convert to Int16 little-endian
            let clipped = max(-1.0, min(1.0, avg))
            let intSample = Int16(clipped * Float(Int16.max))
            interleavedMono.append(intSample)
        }

        // Create Data from Int16 array (little-endian)
        return interleavedMono.withUnsafeBufferPointer { bufferPtr in
            Data(buffer: bufferPtr)
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
        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            guard let alternatives = response.channel?.alternatives else { return }

            for alt in alternatives {
                if let words = alt.words, !words.isEmpty {
                    // Build sentences per speaker with start/end timestamps
                    var speakerSentences: [String: (text: String, start: Double?, end: Double?)] = [:]

                    for wordInfo in words {
                        let speakerID = wordInfo.speaker.map { "spk_\($0)" } ?? "user"
                        
                        if var entry = speakerSentences[speakerID] {
                            entry.text += wordInfo.word + " "
                            entry.end = wordInfo.end
                            speakerSentences[speakerID] = entry
                        } else {
                            speakerSentences[speakerID] = (
                                text: wordInfo.word + " ",
                                start: wordInfo.start,
                                end: wordInfo.end
                            )
                        }
                    }

                    for (speakerID, entry) in speakerSentences {
                        let trimmedText = entry.text.trimmingCharacters(in: .whitespaces)
                        guard !trimmedText.isEmpty else { continue }
                        
                        artifacts.logEvent(type: "TRANSCRIPT", message: "[\(speakerID)] \(trimmedText)")
                        conversation[speakerID, default: []].append(trimmedText)

                        // Notify delegate – treat every sentence as final
                        let chunk = DeepgramTranscriptChunk(
                            speakerID: speakerID,
                            start_time: entry.start,
                            end_time: entry.end,
                            text: trimmedText,
                            isFinal: true
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
                        isFinal: true
                    )
                    delegate?.speechProcessor(self, didReceiveChunk: chunk)
                    logger.info("Speaker: \(speakerID, privacy: .public), Sentence: \(transcript, privacy: .public)")
                }
            }
        } catch {
            artifacts.logEvent(type: "ERROR", message: "JSON Decoding failed")
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
    public func deconfigureAudioEngine(completion: @escaping () -> Void) {
        // Stop accepting new data immediately
        isRecording = false
        artifacts.logEvent(type: "INFO", message: "Deconfiguring Audio Engine...")
        
        converterNode.removeTap(onBus: 0)
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Mark the input as finished so the writer knows no more data is coming
        guard let _ = assetWriter,
            let _ = assetWriterInput else {
            cleanupEngine()
            completion()
            return
        }
        
        // Trigger the finish asynchronously
        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            
            if let error = self.assetWriter?.error {
                print("Writer Error: \(error.localizedDescription)")
            } else {
                print("File finalized successfully.")
            }
            
            // Now it is safe to tear down the audio engine
            self.cleanupEngine()
            
            // Finally, exit the script/process
            completion()
        }
    }
}

