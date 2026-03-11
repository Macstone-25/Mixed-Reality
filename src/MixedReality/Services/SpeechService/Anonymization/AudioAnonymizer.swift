//
//  AudioAnonymizer.swift
//  MixedReality
//

import Foundation
import AVFoundation

protocol AudioAnonymizer {
    /// Takes the recorded conversation file, processes it, and returns the output URL.
    /// - Parameters:
    ///   - inputURL: The original recorded audio file
    ///   - outputURL: The intended URL for the anonymized output file
    /// - Returns: The URL of the anonymized output file
    func anonymize(inputURL: URL, outputURL: URL) async throws -> URL?
}
