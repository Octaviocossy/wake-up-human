import AVFoundation
import Foundation

/// The rain player: a `SoundPlaying` with its own volume, independent of the system volume
/// (spec decision 20).
@MainActor
protocol RainPlaying: SoundPlaying {
    /// 0...1. Takes effect at once, while the rain plays or before it starts.
    var volume: Float { get set }
}

/// Plays two `RainSynth`s, one per channel, through an `AVAudioEngine` (spec decision 10): generated
/// in code, no assets. The sound is continuous, which also keeps a Bluetooth speaker from powering
/// itself off overnight (spec decision 9).
///
/// `isPlaying` means "started and not stopped": it stays `true` while the engine is being rebuilt
/// after an output route change, because the rain is meant to be sounding.
@MainActor
final class RainSound: RainPlaying {
    enum StartError: Error {
        case unsupportedFormat
    }

    /// How many times, one second apart, a failed rebuild after a route change is retried.
    private static let rebuildAttempts = 5
    private static let rebuildDelay: Duration = .seconds(1)
    /// Used when the output reports no sample rate, for instance while a device is going away.
    private static let fallbackSampleRate: Double = 48_000

    private(set) var isPlaying = false

    var volume: Float {
        didSet {
            let clamped = min(max(volume, 0), 1)
            if clamped != volume { volume = clamped }
            engine?.mainMixerNode.outputVolume = clamped
        }
    }

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var configurationObserver: NSObjectProtocol?
    private var rebuildTask: Task<Void, Never>?

    init(volume: Float = 0.6) {
        self.volume = min(max(volume, 0), 1)
    }

    func start() throws {
        guard !isPlaying else { return }
        try startEngine()
        isPlaying = true
        Log.audio.info("Rain started")
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        rebuildTask?.cancel()
        rebuildTask = nil
        stopEngine()
        Log.audio.info("Rain stopped")
    }

    // MARK: - Engine

    private func startEngine() throws {
        let engine = AVAudioEngine()
        let sampleRate = Self.outputSampleRate(of: engine)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw StartError.unsupportedFormat
        }

        // Fresh seeds every time: the rain is not the same minute of rain on every start.
        let renderer = RainRenderer(
            sampleRate: sampleRate, leftSeed: .random(in: .min ... .max), rightSeed: .random(in: .min ... .max))
        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            renderer.render(frameCount: Int(frameCount), into: audioBufferList)
        }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = volume

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.outputConfigurationChanged() }
        }
        self.engine = engine
        self.sourceNode = sourceNode

        do {
            try engine.start()
        } catch {
            stopEngine()
            throw error
        }
    }

    private func stopEngine() {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        engine?.stop()
        if let engine, let sourceNode { engine.detach(sourceNode) }
        sourceNode = nil
        engine = nil
    }

    private static func outputSampleRate(of engine: AVAudioEngine) -> Double {
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        return rate > 0 ? rate : fallbackSampleRate
    }

    // MARK: - Route changes

    /// The output device changed (a Bluetooth speaker powered off and macOS fell back to the built-in
    /// speakers, say) and the engine stopped itself: rebuild it against the new output and carry on.
    private func outputConfigurationChanged() {
        guard isPlaying else { return }
        Log.audio.info("Output configuration changed; rebuilding the rain")
        rebuildTask?.cancel()
        rebuildTask = Task { [weak self] in
            for attempt in 1...Self.rebuildAttempts {
                guard let self, !Task.isCancelled, self.isPlaying else { return }
                self.stopEngine()
                do {
                    try self.startEngine()
                    Log.audio.info("Rain resumed after an output change")
                    return
                } catch {
                    Log.audio.error(
                        "Rain rebuild \(attempt)/\(Self.rebuildAttempts) failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
                try? await Task.sleep(for: Self.rebuildDelay)
            }
        }
    }
}

/// Fills the render buffers from two `RainSynth`s, one per channel. Touched only by the audio thread
/// once the engine runs: no locks, no allocation and no logging in `render`.
final class RainRenderer: @unchecked Sendable {
    private var left: RainSynth
    private var right: RainSynth

    init(sampleRate: Double, leftSeed: UInt64, rightSeed: UInt64) {
        left = RainSynth(sampleRate: sampleRate, seed: leftSeed)
        right = RainSynth(sampleRate: sampleRate, seed: rightSeed)
    }

    /// Writes the left synth to the first buffer and the right synth to the second. An output with
    /// one buffer gets the left channel only.
    func render(frameCount: Int, into audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let leftData = buffers.count > 0 ? buffers[0].mData?.assumingMemoryBound(to: Float.self) : nil
        let rightData = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : nil
        for frame in 0..<frameCount {
            let leftSample = left.nextSample()
            let rightSample = right.nextSample()
            leftData?[frame] = leftSample
            rightData?[frame] = rightSample
        }
        return noErr
    }
}
