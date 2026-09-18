import AVFoundation
import Foundation

enum AudioCaptureError: LocalizedError {
    case engineUnavailable
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .engineUnavailable:
            "Yaptype could not start the microphone."
        case .invalidFormat:
            "The microphone returned an audio format Yaptype cannot convert."
        }
    }
}

final class AudioCaptureService: @unchecked Sendable {
    static let sampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private var startedAt: Date?
    private var latestLevel: Float = 0
    private var tapInstalled = false
    private var frozenElapsed: Double?

    var level: Float {
        lock.lock()
        defer { lock.unlock() }
        return latestLevel
    }

    func start() throws {
        try start(clearing: true)
    }

    func start(clearing: Bool) throws {
        if clearing {
            stopAndClear()
        } else {
            pauseCapture()
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioCaptureError.invalidFormat
        }

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.invalidFormat
        }

        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        if clearing {
            startedAt = Date()
            frozenElapsed = nil
        } else if let frozen = frozenElapsed {
            startedAt = Date().addingTimeInterval(-frozen)
            frozenElapsed = nil
        } else if startedAt == nil {
            startedAt = Date()
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer: buffer, outputFormat: outputFormat)
        }
        tapInstalled = true

        engine.prepare()
        try engine.start()
    }

    func pauseCapture() {
        if frozenElapsed == nil {
            frozenElapsed = elapsedSeconds()
        }
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        converter = nil
        lock.lock()
        latestLevel = 0
        lock.unlock()
    }

    func sampleCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    func elapsedSeconds() -> Double {
        if let frozenElapsed { return frozenElapsed }
        return Date().timeIntervalSince(startedAt ?? Date())
    }

    func copySamples(from start: Int, upTo end: Int? = nil) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        let endIndex = min(end ?? samples.count, samples.count)
        let startIndex = min(max(0, start), endIndex)
        return Array(samples[startIndex..<endIndex])
    }

    func stop() -> (samples: [Float], seconds: Double) {
        let duration = elapsedSeconds()
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        converter = nil

        lock.lock()
        let captured = samples
        samples = []
        latestLevel = 0
        lock.unlock()
        startedAt = nil
        frozenElapsed = nil
        return (captured, max(0, duration))
    }

    private func stopAndClear() {
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        lock.lock()
        samples = []
        latestLevel = 0
        lock.unlock()
        startedAt = nil
        frozenElapsed = nil
    }

    private func append(buffer: AVAudioPCMBuffer, outputFormat: AVAudioFormat) {
        guard let converter else { return }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        var provided = false
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            if provided {
                status.pointee = .noDataNow
                return nil
            }
            provided = true
            status.pointee = .haveData
            return buffer
        }
        converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
        converter.reset()
        guard error == nil, let channel = converted.floatChannelData?[0] else { return }

        let frameCount = Int(converted.frameLength)
        guard frameCount > 0 else { return }
        let pointer = UnsafeBufferPointer(start: channel, count: frameCount)
        var peak: Float = 0
        for sample in pointer {
            peak = max(peak, abs(sample))
        }

        lock.lock()
        samples.append(contentsOf: pointer)
        latestLevel = peak
        lock.unlock()
    }
}
