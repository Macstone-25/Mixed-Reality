import Foundation
import AVFoundation
import CoreMedia

// Converts audio buffer to raw PCM16 data for streaming
public func convertAudio(buffer: AVAudioPCMBuffer) -> Data? {
    let audioBuffer = buffer.audioBufferList.pointee.mBuffers
    guard let mData = audioBuffer.mData else { return nil } // mData may be nil, so safely unwrap
    return Data(bytes: mData, count: Int(audioBuffer.mDataByteSize))
}

public func getTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    let timestamp = formatter.string(from: Date())
    return timestamp
}

public func cmSampleBufferFromPCM(_ pcmBuffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
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
    _ = MemoryLayout<AudioBufferList>.size
    
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
