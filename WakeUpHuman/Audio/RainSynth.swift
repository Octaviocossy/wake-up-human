import Foundation

/// Procedural rain (spec decision 10): a bed of soft, low-passed noise plus sparse random drops.
/// Deterministic for a given seed, so tests can check it.
///
/// A plain value with no allocation after `init` and no locking, so `nextSample()` is safe to call
/// from the audio render thread. Its drop slots are a fixed-size array that is only ever mutated in
/// place.
struct RainSynth: Sendable {
    static let maxConcurrentDrops = 16
    static let dropsPerSecond: Double = 14

    /// The bed: noise through a low-pass at about 1.2 kHz and a gentle high-pass at about 80 Hz, which
    /// removes rumble.
    private static let bedLowPassHz: Double = 1_200
    private static let bedHighPassHz: Double = 80
    /// RMS of the bed. Its peaks reach about 3x that, so about 0.25 amplitude.
    private static let bedRMS: Double = 0.08
    /// RMS of uniform noise in -1...1.
    private static let uniformNoiseRMS: Double = 1 / 3.0.squareRoot()

    /// A drop is noise band-passed around a centre of 2-5 kHz, with a peak of 0.05-0.3 and an
    /// exponential decay (time constant) of 8-30 ms.
    private static let dropCentreHz: ClosedRange<Double> = 2_000...5_000
    private static let dropPeak: ClosedRange<Double> = 0.05...0.3
    private static let dropDecaySeconds: ClosedRange<Double> = 0.008...0.030
    /// Quality factor of the drops' band-pass: wide enough to sound like a splash, not a whistle.
    private static let dropQuality: Double = 1.5
    /// A drop's RMS at its start, relative to its peak: noise reaches about twice its RMS.
    private static let dropRMSPerPeak: Double = 0.5
    /// A drop whose envelope fell below this is inaudible, and its slot is free again.
    private static let dropFloor: Double = 0.001

    /// One raindrop: a state-variable band-pass over shared noise, under an exponentially decaying
    /// envelope. `envelope == 0` marks a free slot.
    private struct Drop: Sendable {
        var envelope: Double = 0
        var decay: Double = 0
        var level: Double = 0
        var coefficient: Double = 0
        var damping: Double = 0
        var low: Double = 0
        var band: Double = 0

        var isActive: Bool { envelope > 0 }

        /// Filters one sample of noise and advances the envelope.
        mutating func nextSample(noise: Double) -> Double {
            low += coefficient * band
            let high = noise - low - damping * band
            band += coefficient * high
            let sample = band * damping * level * envelope
            envelope *= decay
            if envelope < RainSynth.dropFloor { envelope = 0 }
            return sample
        }
    }

    let sampleRate: Double

    private var rng: UInt64
    private var bedLowPass: Double = 0
    private var bedRumble: Double = 0
    private let bedLowPassCoefficient: Double
    private let bedRumbleCoefficient: Double
    private let bedGain: Double
    private let dropProbability: Double
    private var drops: [Drop]

    init(sampleRate: Double, seed: UInt64) {
        self.sampleRate = sampleRate
        // One splitmix64 round, so that nearby seeds (1, 2, 3...) start far apart; xorshift64* needs
        // a nonzero state.
        var mixed = seed &+ 0x9E37_79B9_7F4A_7C15
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        mixed ^= mixed >> 31
        rng = mixed == 0 ? 0x9E37_79B9_7F4A_7C15 : mixed

        bedLowPassCoefficient = 1 - exp(-2 * Double.pi * Self.bedLowPassHz / sampleRate)
        bedRumbleCoefficient = 1 - exp(-2 * Double.pi * Self.bedHighPassHz / sampleRate)
        // A one-pole low-pass keeps a fraction sqrt(a / (2 - a)) of white noise's RMS. Dividing it
        // out holds the bed at `bedRMS` whatever the output sample rate is.
        let kept = (bedLowPassCoefficient / (2 - bedLowPassCoefficient)).squareRoot()
        bedGain = Self.bedRMS / (Self.uniformNoiseRMS * kept)
        dropProbability = Self.dropsPerSecond / sampleRate
        drops = Array(repeating: Drop(), count: Self.maxConcurrentDrops)
    }

    /// How many drops are sounding right now.
    var activeDropCount: Int {
        drops.reduce(0) { $0 + ($1.isActive ? 1 : 0) }
    }

    /// The next mono sample in -1...1.
    mutating func nextSample() -> Float {
        // The bed: low-passed noise, minus its own slow (80 Hz) low-passed copy.
        bedLowPass += bedLowPassCoefficient * (noise() - bedLowPass)
        bedRumble += bedRumbleCoefficient * (bedLowPass - bedRumble)
        var sum = (bedLowPass - bedRumble) * bedGain

        if unit() < dropProbability { startDrop() }
        if hasActiveDrop {
            let dropNoise = noise()
            for index in drops.indices where drops[index].isActive {
                sum += drops[index].nextSample(noise: dropNoise)
            }
        }
        return Float(tanh(sum))
    }

    // MARK: - Drops

    private var hasActiveDrop: Bool {
        for drop in drops where drop.isActive { return true }
        return false
    }

    /// Starts a drop in the first free slot; when all 16 are busy the drop is skipped.
    private mutating func startDrop() {
        guard let slot = drops.firstIndex(where: { !$0.isActive }) else { return }
        let centre = value(in: Self.dropCentreHz)
        let peak = value(in: Self.dropPeak)
        let decaySeconds = value(in: Self.dropDecaySeconds)

        var drop = Drop()
        drop.envelope = 1
        drop.decay = exp(-1 / (decaySeconds * sampleRate))
        // Chamberlin state-variable filter; its coefficient is capped to stay stable at low rates.
        drop.coefficient = min(1, 2 * sin(Double.pi * centre / sampleRate))
        drop.damping = 1 / Self.dropQuality
        // A band-pass with unit gain at its centre passes sqrt(pi * centre / (Q * rate)) of white
        // noise's RMS. Dividing it out makes `peak` mean the same at every centre and sample rate.
        let kept = (Double.pi * centre / (Self.dropQuality * sampleRate)).squareRoot()
        drop.level = peak * Self.dropRMSPerPeak / (Self.uniformNoiseRMS * kept)
        drops[slot] = drop
    }

    // MARK: - Random numbers

    /// xorshift64*.
    private mutating func nextBits() -> UInt64 {
        rng ^= rng >> 12
        rng ^= rng << 25
        rng ^= rng >> 27
        return rng &* 0x2545_F491_4F6C_DD1D
    }

    /// Uniform in 0..<1, from the top 53 bits.
    private mutating func unit() -> Double {
        Double(nextBits() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// Uniform in -1...1.
    private mutating func noise() -> Double {
        unit() * 2 - 1
    }

    /// Uniform in `range`.
    private mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
}
