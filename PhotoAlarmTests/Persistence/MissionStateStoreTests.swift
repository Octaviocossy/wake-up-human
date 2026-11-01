import Foundation
import Testing

@testable import PhotoAlarm

struct MissionStateStoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A unique directory that does not exist yet, so the first save also covers creating it.
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    private func makeSession(firstRingAt: Date) -> WakeUpSession {
        WakeUpSession(id: UUID(), openingAlarmID: UUID(), firstRingAt: firstRingAt)
    }

    @Test func aSavedStateLoadsBackIdentically() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MissionStateStore(directory: directory)
        let followUp = UUID()
        var session = makeSession(firstRingAt: now)
        session.followUpIDs = [followUp]
        session.pendingFollowUpID = followUp
        session.followUpsArmed = 1
        session.failedChecks = 5
        session.fallbackSolved = 3
        var finished = makeSession(firstRingAt: now.addingTimeInterval(-3_600))
        finished.completedAt = now.addingTimeInterval(-3_000)
        let state = MissionState(sessions: [finished, session])

        try store.save(state, now: now)

        #expect(try store.load() == state)
    }

    @Test func aMissingFileLoadsAnEmptyState() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(try MissionStateStore(directory: directory).load() == MissionState())
    }

    @Test func aSecondStoreOnTheSameDirectoryReadsWhatTheFirstWrote() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = MissionState(sessions: [makeSession(firstRingAt: now)])

        try MissionStateStore(directory: directory).save(state, now: now)

        #expect(try MissionStateStore(directory: directory).load() == state)
    }

    @Test func sessionsOlderThanSevenDaysAreDroppedOnSave() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MissionStateStore(directory: directory)
        let old = makeSession(firstRingAt: now.addingTimeInterval(-8 * 24 * 3600))
        let recent = makeSession(firstRingAt: now.addingTimeInterval(-6 * 24 * 3600))

        try store.save(MissionState(sessions: [old, recent]), now: now)

        #expect(try store.load().sessions == [recent])
    }

    @Test func savingReplacesThePreviousState() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MissionStateStore(directory: directory)
        try store.save(MissionState(sessions: [makeSession(firstRingAt: now)]), now: now)

        try store.save(MissionState(), now: now)

        #expect(try store.load().sessions.isEmpty)
    }
}
