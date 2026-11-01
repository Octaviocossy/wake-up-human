import Testing

@testable import WakeUpHuman

struct RainSynthTests {
    private static let sampleRate = 48_000.0

    private func samples(seed: UInt64, count: Int) -> [Float] {
        var synth = RainSynth(sampleRate: Self.sampleRate, seed: seed)
        return (0..<count).map { _ in synth.nextSample() }
    }

    @Test func theSameSeedGivesTheSameFirstThousandSamples() {
        #expect(samples(seed: 42, count: 1_000) == samples(seed: 42, count: 1_000))
    }

    @Test func differentSeedsGiveDifferentSamples() {
        #expect(samples(seed: 1, count: 1_000) != samples(seed: 2, count: 1_000))
    }

    @Test func everySampleStaysWithinFullScaleOverTwoSeconds() {
        var synth = RainSynth(sampleRate: Self.sampleRate, seed: 7)
        for _ in 0..<Int(2 * Self.sampleRate) {
            let sample = synth.nextSample()
            #expect((-1...1).contains(sample))
        }
    }

    @Test(arguments: [44_100.0, 48_000.0, 96_000.0])
    func theLevelIsAudibleAndNotClippingAtEverySampleRate(sampleRate: Double) {
        var synth = RainSynth(sampleRate: sampleRate, seed: 11)
        var sumOfSquares = 0.0
        let count = Int(sampleRate)
        for _ in 0..<count {
            let sample = Double(synth.nextSample())
            sumOfSquares += sample * sample
        }
        let rms = (sumOfSquares / Double(count)).squareRoot()
        #expect(rms > 0.02)
        #expect(rms < 0.5)
    }

    @Test func dropsHappenAndNeverExceedTheirSlots() {
        var synth = RainSynth(sampleRate: Self.sampleRate, seed: 3)
        #expect(synth.activeDropCount == 0)
        var mostAtOnce = 0
        for _ in 0..<Int(5 * Self.sampleRate) {
            _ = synth.nextSample()
            mostAtOnce = max(mostAtOnce, synth.activeDropCount)
        }
        #expect(mostAtOnce > 0)
        #expect(mostAtOnce <= RainSynth.maxConcurrentDrops)
    }

    @Test func dropsStartAtAboutTheirRate() {
        var synth = RainSynth(sampleRate: Self.sampleRate, seed: 5)
        var starts = 0
        var wasSounding = false
        let seconds = 60
        for _ in 0..<(seconds * Int(Self.sampleRate)) {
            _ = synth.nextSample()
            // Drops last tens of milliseconds and often overlap, so count the moments the number of
            // sounding drops rises instead of the moments one is sounding.
            let isSounding = synth.activeDropCount > 0
            if isSounding && !wasSounding { starts += 1 }
            wasSounding = isSounding
        }
        // 14 drops a second, some of them overlapping: far more than one a second, far fewer than 14.
        #expect(starts > seconds)
        #expect(starts < Int(RainSynth.dropsPerSecond) * seconds)
    }

    @Test func dropsAddEnergyAboveTheBed() {
        // The bed is low-passed at 1.2 kHz and the drops sit at 2-5 kHz, so the signal's second
        // difference (a crude high-pass) is larger on average while a drop sounds.
        var synth = RainSynth(sampleRate: Self.sampleRate, seed: 9)
        var older: Float = 0
        var oldest: Float = 0
        var withDrops = (energy: 0.0, count: 0)
        var bedOnly = (energy: 0.0, count: 0)
        for _ in 0..<Int(20 * Self.sampleRate) {
            let sample = synth.nextSample()
            let high = Double(sample - 2 * older + oldest)
            if synth.activeDropCount > 0 {
                withDrops = (withDrops.energy + high * high, withDrops.count + 1)
            } else {
                bedOnly = (bedOnly.energy + high * high, bedOnly.count + 1)
            }
            oldest = older
            older = sample
        }
        #expect(withDrops.count > 0)
        #expect(bedOnly.count > 0)
        #expect(withDrops.energy / Double(withDrops.count) > bedOnly.energy / Double(bedOnly.count))
    }
}
