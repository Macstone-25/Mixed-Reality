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
  - sampleRate: The audio sample rate in Hz (default: 48000)
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
    
    init(sampleRate: Double = 48000, channels: AVAudioChannelCount = 1, interleaved: Bool = true) {
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
    }
    
    // Sets up the audio engine and tap to capture and stream live audio
    private func configureAudioEngine() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)
        
        // Installing a "tap" allows us to read audio buffers in real-time as they pass through this node
        converterNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, time in
            if let data = self.convertAudio(buffer: buffer) {
                self.socket.write(data: data)
            }
        }
        
        audioEngine.connect(inputNode, to: converterNode, format: inputFormat)
        audioEngine.connect(converterNode, to: sinkNode, format: inputFormat)
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            logger.info("Audio engine started.")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        // Request permission synchronously or handle the async result before proceeding
        session.requestRecordPermission { granted in
            if !granted {
                self.logger.error("Microphone permission denied.")
                return
            }
            DispatchQueue.main.async {
                do {
                    try session.setCategory(.playAndRecord,
                                            options: [.duckOthers, .allowBluetooth])
                    try session.setMode(.measurement) // or .voiceChat / .default per use-case
                    // Optionally set preferred sample rate if you truly need it:
                    // try session.setPreferredSampleRate(self.sampleRate)
                    try session.setActive(true, options: [])
                    self.prepareAudioGraphAfterSessionActivation()
                } catch {
                    self.logger.error("Failed to configure AVAudioSession: \(error.localizedDescription)")
                }
            }
        }
    }

    // Called only after AVAudioSession is active
    private func prepareAudioGraphAfterSessionActivation() {
        let inputNode = audioEngine.inputNode

        // Query the actual hardware format AFTER activation
        let nativeFormat = inputNode.inputFormat(forBus: 0)
        let channelCount = nativeFormat.channelCount
        let sampleRate = nativeFormat.sampleRate

        guard channelCount > 0, sampleRate > 0 else {
            logger.error("Invalid native input format — channels: \(channelCount), sampleRate: \(sampleRate)")
            // Consider fallback or retry after a short delay
            return
        }

        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)

        // Install the tap using the node's own format by passing `nil` or `nativeFormat`.
        // Passing nil tells AVAudioNode to use its output format; both are acceptable.
        converterNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { buffer, when in
            // Convert from whatever the device provides (likely Float32) to Int16 linear16
            // and downmix channels to mono if Deepgram expects mono.
            guard let pcmData = self.convertBufferToPCM16(buffer: buffer, targetChannelCount: 1) else { return }
            self.socket.write(data: pcmData)
        }

        // Connect nodes using the same valid format — keep graph formats consistent
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

    
    // Converts audio buffer to raw PCM16 data for streaming
    private func convertAudio(buffer: AVAudioPCMBuffer) -> Data? {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let mData = audioBuffer.mData else { return nil } // mData may be nil, so safely unwrap
        return Data(bytes: mData, count: Int(audioBuffer.mDataByteSize))
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
            logger.error("Failed to decode Deepgram JSON: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Cleans up audio engine and WebSocket, stopping all streaming activity
    public func deconfigureAudioEngine() {
        conversation.removeAll()
        audioEngine.reset() // Clears connections between nodes
        audioEngine.stop()
        converterNode.removeTap(onBus: 0)
        socket.disconnect(closeCode: 1000)
        socket.delegate = nil
    }
}
