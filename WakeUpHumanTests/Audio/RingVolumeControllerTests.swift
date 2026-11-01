import Foundation
import Testing

@testable import WakeUpHuman

@MainActor
struct RingVolumeControllerTests {
    private let startedAt = Date(timeIntervalSince1970: 1_000_000)
    private let userVolume = VolumeSnapshot(deviceUID: "speaker-uid", volume: 0.35, isMuted: true)

    private let volume: SystemVolumeFake
    private let ticker = TickerSpy()
    private let defaults: UserDefaults
    private let suiteName = "test-\(UUID().uuidString)"
    private let controller: RingVolumeController

    init() {
        volume = SystemVolumeFake(currentSnapshot: userVolume)
        defaults = UserDefaults(suiteName: suiteName)!
        controller = RingVolumeController(volume: volume, ticker: ticker, defaults: defaults)
    }

    private func storedSnapshot() -> VolumeSnapshot? {
        guard let data = defaults.data(forKey: RingVolumeController.pendingRestoreKey) else { return nil }
        return try? JSONDecoder().decode(VolumeSnapshot.self, from: data)
    }

    private func finish() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: begin

    @Test func beginPersistsTheSnapshotUnmutesSetsTheStartVolumeAndStartsTheTicker() {
        defer { finish() }
        controller.begin(now: startedAt)

        #expect(storedSnapshot() == userVolume)
        #expect(!volume.setMutedCalls.isEmpty)
        #expect(volume.setMutedCalls.allSatisfy { !$0 })
        #expect(volume.setVolumeCalls == [0.35])
        #expect(ticker.isRunning)
        #expect(ticker.intervals == [RingVolumeController.tickInterval])
        #expect(controller.state == .ramping(percent: 35, secondsToMax: 30))
    }

    @Test func beginWhileARingHoldsTheVolumeKeepsTheOriginalSnapshot() {
        defer { finish() }
        controller.begin(now: startedAt)
        volume.currentSnapshot = VolumeSnapshot(deviceUID: "speaker-uid", volume: 1, isMuted: false)

        controller.begin(now: startedAt.addingTimeInterval(10))
        controller.end()

        #expect(volume.restoredSnapshots == [userVolume])
        #expect(ticker.startCount == 1)
    }

    @Test func beginFirstReturnsAVolumeLeftBehindByAnEarlierRing() {
        defer { finish() }
        let leftBehind = VolumeSnapshot(deviceUID: "speaker-uid", volume: 0.2, isMuted: false)
        defaults.set(try? JSONEncoder().encode(leftBehind), forKey: RingVolumeController.pendingRestoreKey)

        controller.begin(now: startedAt)

        #expect(volume.restoredSnapshots == [leftBehind])
        #expect(storedSnapshot() == userVolume)
    }

    @Test func startingAtMaximumNeedsNoTicker() {
        defer { finish() }
        volume.currentSnapshot = VolumeSnapshot(deviceUID: "speaker-uid", volume: 1, isMuted: false)

        controller.begin(now: startedAt)

        #expect(controller.state == .atMaximum)
        #expect(!ticker.isRunning)
        #expect(volume.setVolumeCalls == [1])
    }

    // MARK: ramp

    @Test func ticksFollowTheRampOnTheCurrentDevice() {
        defer { finish() }
        controller.begin(now: startedAt)

        controller.tick(now: startedAt.addingTimeInterval(12))
        #expect(controller.state == .ramping(percent: 61, secondsToMax: 18))
        #expect(abs((volume.setVolumeCalls.last ?? 0) - 0.61) < 1e-6)

        controller.tick(now: startedAt.addingTimeInterval(29.5))
        #expect(controller.state == .ramping(percent: 99, secondsToMax: 1))
    }

    @Test func everyTickUnmutesAgainInCaseTheOutputMoved() {
        defer { finish() }
        controller.begin(now: startedAt)
        let unmutesAfterBegin = volume.setMutedCalls.count

        controller.tick(now: startedAt.addingTimeInterval(0.5))
        controller.tick(now: startedAt.addingTimeInterval(1))

        #expect(volume.setMutedCalls.count == unmutesAfterBegin + 2)
        #expect(volume.setMutedCalls.allSatisfy { !$0 })
    }

    @Test func atThirtySecondsTheStateIsAtMaximumAndTheTickerStops() {
        defer { finish() }
        controller.begin(now: startedAt)

        controller.tick(now: startedAt.addingTimeInterval(30))

        #expect(controller.state == .atMaximum)
        #expect(volume.setVolumeCalls.last == 1)
        #expect(!ticker.isRunning)
    }

    @Test func theTickerCallbackAdvancesTheRamp() {
        defer { finish() }
        controller.begin(now: Date())
        let callsBefore = volume.setVolumeCalls.count

        ticker.fire()

        #expect(volume.setVolumeCalls.count == callsBefore + 1)
    }

    @Test func publishesEveryStateChangeOnce() {
        defer { finish() }
        var states: [RingVolumeController.State] = []
        controller.onStateChange = { states.append($0) }

        controller.begin(now: startedAt)
        controller.tick(now: startedAt)  // same state again: not published twice
        controller.tick(now: startedAt.addingTimeInterval(30))
        controller.end()

        #expect(states == [.ramping(percent: 35, secondsToMax: 30), .atMaximum, .idle])
    }

    // MARK: end

    @Test func endRestoresTheExactSnapshotAndClearsTheKey() {
        defer { finish() }
        controller.begin(now: startedAt)
        controller.tick(now: startedAt.addingTimeInterval(12))

        controller.end()

        #expect(volume.restoredSnapshots == [userVolume])
        #expect(storedSnapshot() == nil)
        #expect(controller.state == .idle)
        #expect(!ticker.isRunning)
    }

    @Test func aSecondEndDoesNothing() {
        defer { finish() }
        controller.begin(now: startedAt)
        controller.end()
        let stopsAfterFirstEnd = ticker.stopCount

        controller.end()

        #expect(volume.restoredSnapshots == [userVolume])
        #expect(ticker.stopCount == stopsAfterFirstEnd)
    }

    @Test func endWithoutABeginDoesNothing() {
        defer { finish() }
        controller.end()

        #expect(volume.restoredSnapshots.isEmpty)
        #expect(controller.state == .idle)
    }

    @Test func aRefusedRestoreStillClearsTheKey() {
        defer { finish() }
        volume.restoreResult = false
        controller.begin(now: startedAt)

        controller.end()

        #expect(storedSnapshot() == nil)
        #expect(controller.state == .idle)
    }

    // MARK: recovery

    @Test func restorePendingRestoresAStoredSnapshotAndClearsIt() {
        defer { finish() }
        defaults.set(try? JSONEncoder().encode(userVolume), forKey: RingVolumeController.pendingRestoreKey)

        controller.restorePendingIfNeeded()

        #expect(volume.restoredSnapshots == [userVolume])
        #expect(storedSnapshot() == nil)
    }

    @Test func restorePendingDoesNothingWhenNothingIsStored() {
        defer { finish() }
        controller.restorePendingIfNeeded()

        #expect(volume.restoredSnapshots.isEmpty)
    }

    @Test func restorePendingDiscardsAnUnreadableValue() {
        defer { finish() }
        defaults.set(Data("not json".utf8), forKey: RingVolumeController.pendingRestoreKey)

        controller.restorePendingIfNeeded()

        #expect(volume.restoredSnapshots.isEmpty)
        #expect(defaults.data(forKey: RingVolumeController.pendingRestoreKey) == nil)
    }

    @Test func restorePendingLeavesARunningRingsSnapshotAlone() {
        defer { finish() }
        controller.begin(now: startedAt)

        controller.restorePendingIfNeeded()

        #expect(volume.restoredSnapshots.isEmpty)
        #expect(storedSnapshot() == userVolume)
    }

    // MARK: no settable volume

    @Test func aDeviceWithNoVolumeIsUnavailableAndNothingIsTouched() {
        defer { finish() }
        volume.currentSnapshot = nil

        controller.begin(now: startedAt)

        #expect(controller.state == .unavailable)
        #expect(volume.setVolumeCalls.isEmpty)
        #expect(volume.setMutedCalls.isEmpty)
        #expect(storedSnapshot() == nil)
        #expect(!ticker.isRunning)
    }

    @Test func endAfterAnUnavailableDeviceRestoresNothing() {
        defer { finish() }
        volume.currentSnapshot = nil
        controller.begin(now: startedAt)

        controller.end()

        #expect(volume.restoredSnapshots.isEmpty)
        #expect(controller.state == .idle)
    }
}
