import Foundation

/// Linear ramp of the system volume from where it was to maximum over about 30 s (decision 8).
struct VolumeRamp: Equatable, Sendable {
    static let duration: TimeInterval = 30

    let start: Float32
    let startedAt: Date

    /// `start + (1 - start) * clamp(elapsed / duration, 0...1)`; exactly 1 once the ramp is complete.
    func volume(at now: Date) -> Float32 {
        let start = min(max(start, 0), 1)
        let progress = min(max(elapsed(at: now) / Self.duration, 0), 1)
        guard progress < 1 else { return 1 }
        return start + (1 - start) * Float32(progress)
    }

    /// Whole seconds left before maximum, rounded up, never below 0.
    func secondsToMaximum(at now: Date) -> Int {
        guard !isComplete(at: now) else { return 0 }
        return Int((Self.duration - max(elapsed(at: now), 0)).rounded(.up))
    }

    /// `true` once the volume has reached maximum — at once when it started there.
    func isComplete(at now: Date) -> Bool {
        elapsed(at: now) >= Self.duration || start >= 1
    }

    private func elapsed(at now: Date) -> TimeInterval {
        now.timeIntervalSince(startedAt)
    }
}
