import Foundation

/// One loud, pulsing alarm tone (spec decision 19): bursts of a bright tone — four 120 ms beeps
/// 80 ms apart, then 600 ms of silence; a 1.4 s cycle. 5 ms attack/release ramps avoid clicks.
///
/// A plain value with no allocation and no locking, so `nextSample()` is safe to call from the
/// audio render thread.
struct ToneSynth: Sendable {
    static let frequency: Double = 880
    static let beepDuration: Double = 0.12
    static let beepGap: Double = 0.08
    static let beepsPerCycle = 4
    static let cyclePause: Double = 0.6
    static let rampDuration: Double = 0.005
    static var cycleDuration: Double { Double(beepsPerCycle) * (beepDuration + beepGap) + cyclePause }

    /// Weight of the third harmonic relative to the fundamental.
    private static let harmonicWeight: Double = 0.35
    /// The largest value of `sin(x) + harmonicWeight * sin(3x)`, so the waveform can be scaled to
    /// fill the headroom exactly rather than by the looser bound `1 + harmonicWeight`.
    private static let waveformPeak: Double = 0.9548
    /// Peak level of the output, leaving a little headroom below full scale.
    private static let headroom: Double = 0.9

    let sampleRate: Double
    private(set) var sampleIndex: Int64 = 0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// Envelope 0...1 at time `t` seconds into the sound.
    static func envelope(at t: Double) -> Double {
        guard t >= 0 else { return 0 }
        let slot = beepDuration + beepGap
        let positionInCycle = t.truncatingRemainder(dividingBy: cycleDuration)
        guard positionInCycle < Double(beepsPerCycle) * slot else { return 0 }
        let positionInBeep = positionInCycle.truncatingRemainder(dividingBy: slot)
        guard positionInBeep < beepDuration else { return 0 }
        let attack = positionInBeep / rampDuration
        let release = (beepDuration - positionInBeep) / rampDuration
        return min(1, attack, release)
    }

    /// The next mono sample in -1...1: a fundamental plus a softer third harmonic (brighter, louder
    /// at the same peak), times the envelope, times 0.9 headroom.
    mutating func nextSample() -> Float {
        let t = Double(sampleIndex) / sampleRate
        sampleIndex &+= 1
        let envelope = Self.envelope(at: t)
        guard envelope > 0 else { return 0 }
        let phase = 2 * Double.pi * Self.frequency * t
        let wave = (sin(phase) + Self.harmonicWeight * sin(3 * phase)) / Self.waveformPeak
        return Float(wave * envelope * Self.headroom)
    }
}
