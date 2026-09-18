import AVFoundation
import Foundation
import UniformTypeIdentifiers

enum AudioFileDecoderError: LocalizedError {
    case unsupported
    case noAudioTrack
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "That file type is not supported. Use MP3, WAV, M4A, MP4, or MOV."
        case .noAudioTrack:
            "Yaptype could not find an audio track in that file."
        case .decodeFailed:
            "Yaptype could not decode that file."
        }
    }
}

enum AudioFileDecoder {
    static let audioExtensions = ["mp3", "wav", "m4a", "caf", "aiff", "aif", "flac", "aac"]
    static let videoExtensions = ["mp4", "mov", "m4v"]
    static var allowedExtensions: [String] { audioExtensions + videoExtensions }

    static var contentTypes: [UTType] {
        [
            .audio,
            .movie,
            .mpeg4Movie,
            .quickTimeMovie,
            .mp3,
            .wav,
            .mpeg4Audio
        ]
    }

    static func supports(_ url: URL) -> Bool {
        allowedExtensions.contains(url.pathExtension.lowercased())
    }

    static func decode(_ url: URL) async throws -> (samples: [Float], seconds: Double) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let decoded = try? decodeAudioFile(url) {
            return decoded
        }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("yaptype-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: temp) }
        try await extractAudio(from: url, to: temp)
        return try decodeAudioFile(temp)
    }

    private static func decodeAudioFile(_ url: URL) throws -> (samples: [Float], seconds: Double) {
        let file = try AVAudioFile(forReading: url)
        let inputFormat = file.processingFormat
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioCaptureService.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioFileDecoderError.decodeFailed
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioFileDecoderError.decodeFailed
        }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount)
        else {
            throw AudioFileDecoderError.decodeFailed
        }
        try file.read(into: inputBuffer)

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 32
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw AudioFileDecoderError.decodeFailed
        }

        var provided = false
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            if provided {
                status.pointee = .noDataNow
                return nil
            }
            provided = true
            status.pointee = .haveData
            return inputBuffer
        }
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        if error != nil {
            throw AudioFileDecoderError.decodeFailed
        }

        guard let channel = outputBuffer.floatChannelData?[0] else {
            throw AudioFileDecoderError.decodeFailed
        }
        let count = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channel, count: count))
        let seconds = Double(count) / AudioCaptureService.sampleRate
        return (samples, seconds)
    }

    private static func extractAudio(from url: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else {
            throw AudioFileDecoderError.noAudioTrack
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioFileDecoderError.decodeFailed
        }
        session.outputURL = destination
        session.outputFileType = .m4a
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously { [session] in
                if session.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: session.error ?? AudioFileDecoderError.decodeFailed)
                }
            }
        }
    }
}
