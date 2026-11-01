import Testing

@testable import WakeUpHuman

struct ToneSynthTests {
    private static let slot = ToneSynth.beepDuration + ToneSynth.beepGap

    @Test(arguments: 0..<ToneSynth.beepsPerCycle)
    func envelopeIsFullInTheMiddleOfEachBeep(beep: Int) {
        let middle = Double(beep) * Self.slot + ToneSynth.beepDuration / 2
        #expect(ToneSynth.envelope(at: middle) == 1)
    }

    @Test(arguments: 0..<ToneSynth.beepsPerCycle)
    func envelopeIsZeroInEachGapAndInThePause(beep: Int) {
        let middleOfGap = Double(beep) * Self.slot + ToneSynth.beepDuration + ToneSynth.beepGap / 2
        #expect(ToneSynth.envelope(at: middleOfGap) == 0)
    }

    @Test func envelopeIsZeroThroughTheEndOfTheCycle() {
        let pauseStart = Double(ToneSynth.beepsPerCycle) * Self.slot
        let middleOfPause = pauseStart + ToneSynth.cyclePause / 2
        #expect(ToneSynth.envelope(at: middleOfPause) == 0)
        #expect(ToneSynth.envelope(at: ToneSynth.cycleDuration - 0.001) == 0)
    }

    @Test func envelopeRampsInAndOutOfEachBeepWithoutAClick() {
        #expect(ToneSynth.envelope(at: 0) == 0)
        #expect(abs(ToneSynth.envelope(at: ToneSynth.rampDuration / 2) - 0.5) < 1e-9)
        #expect(abs(ToneSynth.envelope(at: ToneSynth.beepDuration - ToneSynth.rampDuration / 2) - 0.5) < 1e-9)
    }

    @Test(arguments: [0.0, 0.003, 0.06, 0.119, 0.15, 0.26, 0.7, 0.9, 1.2, 1.39])
    func cycleRepeatsEveryCycleDuration(offset: Double) {
        let first = ToneSynth.envelope(at: offset)
        #expect(abs(ToneSynth.envelope(at: offset + ToneSynth.cycleDuration) - first) < 1e-9)
        #expect(abs(ToneSynth.envelope(at: offset + 7 * ToneSynth.cycleDuration) - first) < 1e-9)
    }

    @Test func envelopeIsZeroBeforeTheSoundStarts() {
        #expect(ToneSynth.envelope(at: -0.5) == 0)
    }

    @Test func samplesStayWithinFullScaleOverTwoCycles() {
        let sampleRate = 48_000.0
        var synth = ToneSynth(sampleRate: sampleRate)
        let count = Int(2 * ToneSynth.cycleDuration * sampleRate)
        var peak: Float = 0
        for _ in 0..<count {
            let sample = synth.nextSample()
            #expect((-1...1).contains(sample))
            peak = max(peak, abs(sample))
        }
        // Loud, not merely in range: the tone fills its headroom.
        #expect(peak > 0.85)
    }

    @Test func silenceInThePauseAndSoundInTheBeeps() {
        let sampleRate = 48_000.0
        var synth = ToneSynth(sampleRate: sampleRate)
        var beepEnergy: Float = 0
        var pauseEnergy: Float = 0
        let pauseStart = Double(ToneSynth.beepsPerCycle) * Self.slot
        for index in 0..<Int(ToneSynth.cycleDuration * sampleRate) {
            let sample = synth.nextSample()
            let time = Double(index) / sampleRate
            if time < ToneSynth.beepDuration {
                beepEnergy += abs(sample)
            } else if time >= pauseStart {
                pauseEnergy += abs(sample)
            }
        }
        #expect(beepEnergy > 0)
        #expect(pauseEnergy == 0)
    }

    @Test func sampleIndexAdvancesOncePerSample() {
        var synth = ToneSynth(sampleRate: 48_000)
        for _ in 0..<10 { _ = synth.nextSample() }
        #expect(synth.sampleIndex == 10)
    }
}
