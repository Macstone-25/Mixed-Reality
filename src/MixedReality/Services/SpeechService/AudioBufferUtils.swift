//
//  AudioBufferUtils.swift
//  MixedReality
//

import AVFoundation

enum AudioBufferUtils {
    /// Converts an Int16/Float32/Float64 buffer to PCM16 and downmix if needed
    static func convertBufferToPCM16(buffer: AVAudioPCMBuffer, targetChannelCount: AVAudioChannelCount) -> Data? {
        let format = buffer.format
        let frameLength = Int(buffer.frameLength)
        let sourceChannels = Int(format.channelCount)
        let targetChannels = Int(max(1, targetChannelCount))

        guard frameLength > 0 else { return Data() }

        // Prepare a unified sample accessor that returns Float in [-1, 1]
        enum SourceAccessor {
            case f32(ptrs: [UnsafePointer<Float>])
            case f64(ptrs: [UnsafePointer<Double>])
            case i16(ptrs: [UnsafePointer<Int16>])
        }

        let accessor: SourceAccessor
        switch format.commonFormat {
        case .pcmFormatFloat32:
            guard let base = buffer.floatChannelData else { return nil }
            var ptrs: [UnsafePointer<Float>] = []
            ptrs.reserveCapacity(sourceChannels)
            for ch in 0..<sourceChannels {
                #if swift(>=5.9)
                let p: UnsafePointer<Float> = UnsafePointer(base[ch])
                #else
                guard let inner = base[ch] else { return nil }
                let p: UnsafePointer<Float> = UnsafePointer(inner)
                #endif
                ptrs.append(p)
            }
            accessor = .f32(ptrs: ptrs)
        case .pcmFormatFloat64:
            guard let base = buffer.floatChannelData else { return nil }
            var ptrs: [UnsafePointer<Double>] = []
            ptrs.reserveCapacity(sourceChannels)
            for ch in 0..<sourceChannels {
                #if swift(>=5.9)
                let raw = UnsafeRawPointer(base[ch])
                #else
                guard let inner = base[ch] else { return nil }
                let raw = UnsafeRawPointer(inner)
                #endif
                let rp = raw.assumingMemoryBound(to: Double.self)
                ptrs.append(rp)
            }
            accessor = .f64(ptrs: ptrs)
        case .pcmFormatInt16:
            guard let base = buffer.int16ChannelData else { return nil }
            var ptrs: [UnsafePointer<Int16>] = []
            ptrs.reserveCapacity(sourceChannels)
            for ch in 0..<sourceChannels {
                #if swift(>=5.9)
                let p: UnsafePointer<Int16> = UnsafePointer(base[ch])
                #else
                guard let inner = base[ch] else { return nil }
                let p: UnsafePointer<Int16> = UnsafePointer(inner)
                #endif
                ptrs.append(p)
            }
            accessor = .i16(ptrs: ptrs)
        default:
            fatalError("Unsupported audio buffer format")
        }

        // Unified getter converting any source format to Float [-1, 1]
        @inline(__always)
        func sample(_ ch: Int, _ frame: Int) -> Float {
            switch accessor {
            case .f32(let ptrs):
                return ptrs[ch][frame]
            case .f64(let ptrs):
                return Float(ptrs[ch][frame])
            case .i16(let ptrs):
                let v = ptrs[ch][frame]
                return Float(v) / Float(Int16.max)
            }
        }

        // Prepare interleaved PCM16 output buffer (frameLength * targetChannels)
        var interleaved = [Int16](repeating: 0, count: frameLength * targetChannels)

        // Helper to clip and convert float sample [-1, 1] -> Int16
        @inline(__always)
        func toInt16(_ x: Float) -> Int16 {
            let clipped = max(-1.0, min(1.0, x))
            return Int16(clipped * Float(Int16.max))
        }

        // Downmixing rules:
        // - If targetChannels == 1: average all source channels into mono
        // - If targetChannels == 2: split source channels into two groups (L/R) and average within each group
        // - If targetChannels >= sourceChannels: copy/replicate channels to fill target
        // - Else (generic N): group source channels into N groups and average each group
        if targetChannels == 1 {
            // Mono downmix
            for frameIndex in 0..<frameLength {
                var sum: Float = 0
                for ch in 0..<sourceChannels { sum += sample(ch, frameIndex) }
                let avg = sum / Float(sourceChannels)
                interleaved[frameIndex] = toInt16(avg)
            }
        } else if targetChannels == 2 {
            // Stereo downmix: average first half as Left, second half as Right
            // If only one source channel, duplicate to both
            let half = max(1, sourceChannels / 2)
            let leftRange = 0..<half
            let rightRange = half..<sourceChannels

            for frameIndex in 0..<frameLength {
                var leftSum: Float = 0
                var rightSum: Float = 0

                if sourceChannels == 1 {
                    let v = sample(0, frameIndex)
                    leftSum = v
                    rightSum = v
                } else {
                    for ch in leftRange { leftSum += sample(ch, frameIndex) }
                    for ch in rightRange { rightSum += sample(ch, frameIndex) }

                    if rightRange.isEmpty { rightSum = leftSum }

                    leftSum /= Float(max(1, leftRange.count))
                    rightSum /= Float(max(1, rightRange.count))
                }

                let base = frameIndex * 2
                interleaved[base + 0] = toInt16(leftSum)
                interleaved[base + 1] = toInt16(rightSum)
            }
        } else if targetChannels >= sourceChannels {
            // Expand: copy source channels and replicate last channel if needed
            for frameIndex in 0..<frameLength {
                let base = frameIndex * targetChannels
                for ch in 0..<targetChannels {
                    let srcCh = min(ch, sourceChannels - 1)
                    interleaved[base + ch] = toInt16(sample(srcCh, frameIndex))
                }
            }
        } else {
            // Generic N-channel downmix by grouping source channels into N groups
            for frameIndex in 0..<frameLength {
                let base = frameIndex * targetChannels
                for outCh in 0..<targetChannels {
                    let start = (outCh * sourceChannels) / targetChannels
                    let end = ((outCh + 1) * sourceChannels) / targetChannels
                    var sum: Float = 0
                    let count = max(1, end - start)
                    for srcCh in start..<end { sum += sample(srcCh, frameIndex) }
                    let avg = sum / Float(count)
                    interleaved[base + outCh] = toInt16(avg)
                }
            }
        }

        return interleaved.withUnsafeBufferPointer { Data(buffer: $0) }
    }
    
    /// Converts an AVAudioPCMBuffer to a CMSampleBuffer
    static func cmSampleBufferFromPCM(_ pcmBuffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
        let format = pcmBuffer.format
        let frameCount = pcmBuffer.frameLength
        
        // Create the audio format description
        var formatDesc: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                   asbd: format.streamDescription,
                                                   layoutSize: 0,
                                                   layout: nil,
                                                   magicCookieSize: 0,
                                                   magicCookie: nil,
                                                   extensions: nil,
                                                   formatDescriptionOut: &formatDesc)
        
        guard status == noErr, let desc = formatDesc else { return nil }
        
        // Wrap the PCM data in a CMBlockBuffer
        // We use the AudioBufferList directly from the pcmBuffer
        var blockBuffer: CMBlockBuffer?
        
        // Create block buffer from the memory of the pcmBuffer
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: pcmBuffer.audioBufferList.pointee.mBuffers.mData,
            blockLength: Int(pcmBuffer.audioBufferList.pointee.mBuffers.mDataByteSize),
            blockAllocator: kCFAllocatorNull, // We use null because pcmBuffer owns the memory
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: Int(pcmBuffer.audioBufferList.pointee.mBuffers.mDataByteSize),
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard blockStatus == noErr, let bBuf = blockBuffer else { return nil }
        
        // Set up timing
        // Use the PTS from the buffer if available, otherwise default to zero
        let pts = CMTime(value: 0, timescale: CMTimeScale(format.sampleRate))
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(format.sampleRate)),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )
        
        // Create the sample buffer
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: bBuf,
            formatDescription: desc,
            sampleCount: CMItemCount(frameCount),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        return sampleBuffer
    }
}
