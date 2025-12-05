import AVFoundation
import Starscream
import os

// MARK: - Deepgram response model

struct DeepgramResponse: Codable {
    // Endpointing / finality flags from Deepgram
    let is_final: Bool?        // final transcript for this segment
    let speech_final: Bool?    // Deepgram thinks speech ended

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

// MARK: - SpeechProcessor (visionOS, AVAudioSession)

class SpeechProcessor: WebSocketDelegate {

    // Keeps a running record of all transcripts per speaker
    public private(set) var conversation: [String: [String]] = [:]

    // Logger
    private let logger = Logger(subsystem: "NLP", category: "SpeechProcessor")

    // Audio engine graph
    private let audioEngine = AVAudioEngine()
    private let converterNode = AVAudioMixerNode()
    private let sinkNode = AVAudioMixerNode()

    // Audio format properties (what we *request* / tell Deepgram)
    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let interleaved: Bool

    // Deepgram endpointing window in ms (e.g. 4 seconds)
    private let endpointingMs: Int = 4000

    // Deepgram WebSocket auth
    private let deepgramKey: String

    // WebSocket configured with the same params you used in the CLI version
    private lazy var socket: Starscream.WebSocket = {
        let urlString =
            "wss://api.deepgram.com/v1/listen" +
            "?model=nova-2" +
            "&diarize=true" +
            "&punctuate=true" +
            "&filler_words=true" +
            "&encoding=linear16" +
            "&interim_results=true" +                 // NEW: get partials
            "&sample_rate=\(Int(sampleRate))" +
            "&channels=\(channels)" +
            "&endpointing=\(endpointingMs)" +
            "&vad_events=true"

        guard let url = URL(string: urlString) else {
            fatalError("Invalid WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")
        return Starscream.WebSocket(request: request)
    }()

    weak var delegate: SpeechProcessorDelegate?

    // MARK: - Init

    init(
        sampleRate: Double = 48_000,
        channels: AVAudioChannelCount = 1,
        interleaved: Bool = true
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.interleaved = interleaved

        // Load Deepgram API key from env (same as before)
        guard let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] else {
            fatalError("Deepgram API Key not found.")
        }
        self.deepgramKey = key

        socket.delegate = self

        // visionOS: configure AVAudioSession first, then build audio graph
        configureAudioSession()

        // Connect to Deepgram
        socket.connect()
    }

    // MARK: - Audio engine (visionOS – AVAudioSession)

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        session.requestRecordPermission { granted in
            if !granted {
                self.logger.error("Microphone permission denied.")
                return
            }

            DispatchQueue.main.async {
                do {
                    try session.setCategory(
                        .playAndRecord,
                        options: [.duckOthers, .allowBluetooth]
                    )
                    try session.setMode(.measurement)

                    // If you *really* want to enforce sample rate, you can uncomment:
                    // try session.setPreferredSampleRate(self.sampleRate)

                    try session.setActive(true, options: [])

                    self.prepareAudioGraphAfterSessionActivation()
                } catch {
                    self.logger.error("Failed to configure AVAudioSession: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    /// Called once AVAudioSession is active and the hardware format is valid.
    private func prepareAudioGraphAfterSessionActivation() {
        let inputNode = audioEngine.inputNode

        // Query the actual hardware format AFTER activation
        let nativeFormat = inputNode.inputFormat(forBus: 0)
        let channelCount = nativeFormat.channelCount
        let hardwareSampleRate = nativeFormat.sampleRate

        guard channelCount > 0, hardwareSampleRate > 0 else {
            logger.error("Invalid native input format — channels: \(channelCount), sampleRate: \(hardwareSampleRate)")
            return
        }

        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)

        // Tap the converter node and convert Float32 → mono Int16 (linear16)
        converterNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: nativeFormat
        ) { [weak self] buffer, _ in
            guard
                let self = self,
                let pcmData = self.convertBufferToPCM16(buffer: buffer, targetChannelCount: 1)
            else { return }

            self.socket.write(data: pcmData)
        }

        // Connect nodes using the native/hardware format
        audioEngine.connect(inputNode, to: converterNode, format: nativeFormat)
        audioEngine.connect(converterNode, to: sinkNode, format: nativeFormat)

        do {
            try audioEngine.start()
            logger.info("Audio engine started.")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Convert Float32 buffer to mono PCM16 (little-endian) for Deepgram.
    private func convertBufferToPCM16(
        buffer: AVAudioPCMBuffer,
        targetChannelCount: AVAudioChannelCount = 1
    ) -> Data? {
        let format = buffer.format
        let frameLength = Int(buffer.frameLength)
        let channels = Int(format.channelCount)

        // Typical device format is .pcmFormatFloat32
        guard format.commonFormat == .pcmFormatFloat32,
              let floatChannelData = buffer.floatChannelData
        else {
            // If you ever see this, you can extend it to handle other formats.
            return nil
        }

        var interleavedMono = [Int16]()
        interleavedMono.reserveCapacity(frameLength)

        // Simple downmix: average all channels to mono
        for frameIndex in 0..<frameLength {
            var sampleSum: Float = 0.0
            for ch in 0..<channels {
                sampleSum += floatChannelData[ch][frameIndex]
            }
            let avg = sampleSum / Float(channels)

            // Clamp to [-1, 1] and scale to Int16
            let clipped = max(-1.0, min(1.0, avg))
            let intSample = Int16(clipped * Float(Int16.max))
            interleavedMono.append(intSample)
        }

        return interleavedMono.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
    }

    // MARK: - WebSocket delegate

    func didReceive(event: Starscream.WebSocketEvent,
                    client: any Starscream.WebSocketClient) {
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

    // MARK: - Deepgram JSON → delegate chunks

    public func processJSON(data: Data) {
        // 1) Cheap envelope check; ignore non-Results frames.
        if let envelope = try? JSONDecoder().decode(DeepgramEnvelope.self, from: data),
           let type = envelope.type,
           type != "Results" {
            // Metadata / SpeechStarted / UtteranceEnd / etc.
            return
        }

        // 2) Decode actual Results into our richer model.
        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            guard let alternatives = response.channel?.alternatives else { return }

            // Use Deepgram's speech_final as our "finality" hint
            let finalFlag = response.is_final ?? false

            for alt in alternatives {
                if let words = alt.words, !words.isEmpty {
                    // Group by speaker, build sentence + timestamps
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
                        let trimmed = entry.text.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { continue }

                        conversation[speakerID, default: []].append(trimmed)

                        let chunk = DeepgramTranscriptChunk(
                            speakerID: speakerID,
                            start_time: entry.start,
                            end_time: entry.end,
                            text: trimmed,
                            isFinal: finalFlag
                        )

                        delegate?.speechProcessor(self, didReceiveChunk: chunk)
                        logger.info("Speaker: \(speakerID, privacy: .public), Sentence: \(trimmed, privacy: .public)")
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
            logger.error("Failed to decode Deepgram JSON: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Teardown

    public func deconfigureAudioEngine() {
        conversation.removeAll()
        audioEngine.reset()
        audioEngine.stop()
        converterNode.removeTap(onBus: 0)
        socket.disconnect(closeCode: 1000)
        socket.delegate = nil
    }
}
