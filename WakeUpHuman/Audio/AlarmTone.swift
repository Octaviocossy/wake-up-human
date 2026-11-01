import AVFoundation
import Foundation

/// Plays `ToneSynth` through an `AVAudioEngine` (spec decision 19): one loud, pulsing tone, no assets.
///
/// `isPlaying` means "started and not stopped": it stays `true` while the engine is being rebuilt
/// after an output route change, because the tone is meant to be sounding.
@MainActor
final class AlarmTone: SoundPlaying {
    enum StartError: Error {
        case unsupportedFormat
    }

    /// How many times, one second apart, a failed rebuild after a route change is retried.
    private static let rebuildAttempts = 5
    private static let rebuildDelay: Duration = .seconds(1)
    /// Used when the output reports no sample rate, for instance while a device is going away.
    private static let fallbackSampleRate: Double = 48_000

    private(set) var isPlaying = false

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var configurationObserver: NSObjectProtocol?
    private var rebuildTask: Task<Void, Never>?

    func start() throws {
        guard !isPlaying else { return }
        try startEngine()
        isPlaying = true
        Log.audio.info("Alarm tone started")
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        rebuildTask?.cancel()
        rebuildTask = nil
        stopEngine()
        Log.audio.info("Alarm tone stopped")
    }

    // MARK: - Engine

    private func startEngine() throws {
        let engine = AVAudioEngine()
        let sampleRate = Self.outputSampleRate(of: engine)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw StartError.unsupportedFormat
        }

        let renderer = ToneRenderer(sampleRate: sampleRate)
        // `@Sendable` keeps the block nonisolated. Without it the closure inherits this method's
        // main-actor isolation, Swift 6 checks that isolation on entry, and Core Audio's render thread
        // traps in `_dispatch_assert_queue_fail` on the first buffer.
        let sourceNode = AVAudioSourceNode(format: format) { @Sendable _, _, frameCount, audioBufferList in
            renderer.render(frameCount: Int(frameCount), into: audioBufferList)
        }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1

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
        Log.audio.info("Output configuration changed; rebuilding the alarm tone")
        rebuildTask?.cancel()
        rebuildTask = Task { [weak self] in
            for attempt in 1...Self.rebuildAttempts {
                guard let self, !Task.isCancelled, self.isPlaying else { return }
                self.stopEngine()
                do {
                    try self.startEngine()
                    Log.audio.info("Alarm tone resumed after an output change")
                    return
                } catch {
                    Log.audio.error(
                        "Alarm tone rebuild \(attempt)/\(Self.rebuildAttempts) failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
                try? await Task.sleep(for: Self.rebuildDelay)
            }
        }
    }
}

/// Fills the render buffers from a `ToneSynth`. Touched only by the audio thread once the engine
/// runs: no locks, no allocation and no logging in `render`.
final class ToneRenderer: @unchecked Sendable {
    private var synth: ToneSynth

    init(sampleRate: Double) {
        synth = ToneSynth(sampleRate: sampleRate)
    }

    /// Writes the same mono signal to every channel of `audioBufferList`.
    func render(frameCount: Int, into audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for frame in 0..<frameCount {
            let sample = synth.nextSample()
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                data[frame] = sample
            }
        }
        return noErr
    }
}
