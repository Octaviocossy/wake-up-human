import Foundation
import Testing

@testable import WakeUpHuman

struct VolumeRampTests {
    private let startedAt = Date(timeIntervalSince1970: 1_000_000)

    private func ramp(from start: Float32) -> VolumeRamp {
        VolumeRamp(start: start, startedAt: startedAt)
    }

    @Test func climbsLinearlyFromTheStartToMaximumOverThirtySeconds() {
        let ramp = ramp(from: 0.35)
        #expect(ramp.volume(at: startedAt) == 0.35)
        #expect(abs(ramp.volume(at: startedAt.addingTimeInterval(15)) - 0.675) < 1e-6)
        #expect(ramp.volume(at: startedAt.addingTimeInterval(30)) == 1)
        #expect(ramp.volume(at: startedAt.addingTimeInterval(45)) == 1)
    }

    @Test func staysAtTheStartIfTheClockStepsBack() {
        #expect(ramp(from: 0.35).volume(at: startedAt.addingTimeInterval(-5)) == 0.35)
    }

    @Test func secondsToMaximumRoundsUp() {
        let ramp = ramp(from: 0.35)
        #expect(ramp.secondsToMaximum(at: startedAt) == 30)
        #expect(ramp.secondsToMaximum(at: startedAt.addingTimeInterval(0.2)) == 30)
        #expect(ramp.secondsToMaximum(at: startedAt.addingTimeInterval(14.5)) == 16)
        #expect(ramp.secondsToMaximum(at: startedAt.addingTimeInterval(29.5)) == 1)
    }

    @Test func secondsToMaximumNeverGoesNegative() {
        let ramp = ramp(from: 0.35)
        #expect(ramp.secondsToMaximum(at: startedAt.addingTimeInterval(30)) == 0)
        #expect(ramp.secondsToMaximum(at: startedAt.addingTimeInterval(45)) == 0)
    }

    @Test func isCompleteOnlyOnceThirtySecondsHavePassed() {
        let ramp = ramp(from: 0.35)
        #expect(!ramp.isComplete(at: startedAt))
        #expect(!ramp.isComplete(at: startedAt.addingTimeInterval(29.9)))
        #expect(ramp.isComplete(at: startedAt.addingTimeInterval(30)))
    }

    @Test func startingAtMaximumIsCompleteAtOnce() {
        let ramp = ramp(from: 1)
        #expect(ramp.isComplete(at: startedAt))
        #expect(ramp.volume(at: startedAt) == 1)
        #expect(ramp.secondsToMaximum(at: startedAt) == 0)
    }

    @Test func aMutedSilentStartStillReachesMaximum() {
        let ramp = ramp(from: 0)
        #expect(ramp.volume(at: startedAt) == 0)
        #expect(abs(ramp.volume(at: startedAt.addingTimeInterval(15)) - 0.5) < 1e-6)
        #expect(ramp.volume(at: startedAt.addingTimeInterval(30)) == 1)
    }
}
