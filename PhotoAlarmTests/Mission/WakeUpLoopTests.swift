import Foundation
import Testing

@testable import PhotoAlarm

struct WakeUpLoopTests {
    /// A loop over a unique temporary directory, a fake scheduler and a clock the test moves by hand.
    private struct Fixture {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let clock = TestClock()
        let scheduler = FakeAlarmScheduler()

        var store: MissionStateStore { MissionStateStore(directory: directory) }

        /// A new loop over the same store, as an intent in a fresh process would build.
        func makeLoop() -> WakeUpLoop {
            WakeUpLoop(store: store, scheduler: scheduler, now: { [clock] in clock.now })
        }

        func sessions() throws -> [WakeUpSession] {
            try store.load().sessions
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// Opens a session with a first Stop and returns the loop, the opening alarm and the armed Follow-up.
    private func openSession(
        _ fixture: Fixture, via exit: RingExit = .stop
    ) async throws -> (loop: WakeUpLoop, alarmID: UUID, followUpID: UUID) {
        let loop = fixture.makeLoop()
        let alarmID = UUID()
        try await loop.ringEnded(systemAlarmID: alarmID, via: exit)
        let session = try #require(try fixture.sessions().first)
        return (loop, alarmID, try #require(session.pendingFollowUpID))
    }

    /// Opens a session and fails five Photo checks, which unlocks the Fallback.
    private func openSessionWithFallbackUnlocked(_ fixture: Fixture) async throws -> WakeUpLoop {
        let (loop, _, _) = try await openSession(fixture)
        for _ in 0..<MissionPolicy.fallbackUnlockFailures {
            try await loop.recordPhotoCheck(.noMatch)
        }
        return loop
    }

    // MARK: Ring

    @Test func aFirstStopOpensASessionAndArmsOneFollowUpAMinuteOut() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (_, alarmID, followUpID) = try await openSession(fixture)

        let sessions = try fixture.sessions()
        #expect(sessions.count == 1)
        let session = try #require(sessions.first)
        #expect(session.openingAlarmID == alarmID)
        #expect(session.firstRingAt == fixture.clock.now)
        #expect(session.followUpsArmed == 1)
        #expect(session.followUpIDs == [followUpID])
        #expect(fixture.scheduler.oneOffs == [followUpID: fixture.clock.now.addingTimeInterval(60)])
    }

    @Test func takePhotoArmsAFollowUpExactlyLikeStop() async throws {
        let stopFixture = Fixture()
        let photoFixture = Fixture()
        defer {
            stopFixture.cleanUp()
            photoFixture.cleanUp()
        }
        let (_, _, stopFollowUp) = try await openSession(stopFixture, via: .stop)
        let (_, _, photoFollowUp) = try await openSession(photoFixture, via: .takePhoto)

        let stopSession = try #require(try stopFixture.sessions().first)
        let photoSession = try #require(try photoFixture.sessions().first)
        #expect(photoSession.followUpsArmed == stopSession.followUpsArmed)
        #expect(
            photoFixture.scheduler.oneOffs[photoFollowUp] == photoFixture.clock.now.addingTimeInterval(60))
        #expect(stopFixture.scheduler.oneOffs[stopFollowUp] == stopFixture.clock.now.addingTimeInterval(60))
    }

    @Test func aStopOnTheFollowUpKeepsTheSessionAndArmsTheNext() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, firstFollowUp) = try await openSession(fixture)
        fixture.clock.advance(by: 60)

        try await loop.ringEnded(systemAlarmID: firstFollowUp, via: .stop)

        let sessions = try fixture.sessions()
        #expect(sessions.count == 1)
        let session = try #require(sessions.first)
        #expect(session.followUpsArmed == 2)
        let secondFollowUp = try #require(session.pendingFollowUpID)
        #expect(secondFollowUp != firstFollowUp)
        #expect(session.followUpIDs == [firstFollowUp, secondFollowUp])
        #expect(fixture.scheduler.oneOffs[secondFollowUp] == fixture.clock.now.addingTimeInterval(60))
    }

    @Test func noFollowUpIsArmedAfterTheTwentieth() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, _) = try await openSession(fixture)
        // Rings 10 s apart keep the 20-minute window open while the cap is reached.
        for _ in 1..<MissionPolicy.followUpCap {
            fixture.clock.advance(by: 10)
            let pending = try #require(try fixture.sessions().first?.pendingFollowUpID)
            try await loop.ringEnded(systemAlarmID: pending, via: .stop)
        }
        #expect(try fixture.sessions().first?.followUpsArmed == 20)
        #expect(fixture.scheduler.oneOffs.count == 20)

        fixture.clock.advance(by: 10)
        let last = try #require(try fixture.sessions().first?.pendingFollowUpID)
        try await loop.ringEnded(systemAlarmID: last, via: .stop)

        let session = try #require(try fixture.sessions().first)
        #expect(session.followUpsArmed == 20)
        #expect(session.pendingFollowUpID == nil)
        #expect(fixture.scheduler.oneOffs.count == 20)
    }

    @Test func aPostponedFollowUpThatRingsAnywayStaysInItsSession() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, oldFollowUp) = try await openSession(fixture)
        fixture.clock.advance(by: 30)
        try await loop.postponePendingFollowUps()
        let replacement = try #require(try fixture.sessions().first?.pendingFollowUpID)

        try await loop.ringEnded(systemAlarmID: oldFollowUp, via: .stop)

        let sessions = try fixture.sessions()
        #expect(sessions.count == 1)
        #expect(sessions.first?.pendingFollowUpID == replacement)
        #expect(sessions.first?.followUpsArmed == 1)
    }

    @Test func aFailedSchedulingStillOpensTheSessionAndSurfacesTheError() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let loop = fixture.makeLoop()
        fixture.scheduler.schedulingFails = true

        await #expect(throws: FakeAlarmScheduler.SchedulingFailure.self) {
            try await loop.ringEnded(systemAlarmID: UUID(), via: .stop)
        }

        let session = try #require(try fixture.sessions().first)
        #expect(session.followUpsArmed == 0)
        #expect(session.pendingFollowUpID == nil)
        #expect(try await loop.hasOpenSession())
    }

    // MARK: Which session a Ring belongs to

    @Test func aStopOnAClosedSessionsFollowUpOpensNothing() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, followUp) = try await openSession(fixture)
        try await loop.recordPhotoCheck(.match)
        fixture.clock.advance(by: 60)

        try await loop.ringEnded(systemAlarmID: followUp, via: .stop)

        #expect(try fixture.sessions().count == 1)
        #expect(try await loop.hasOpenSession() == false)
        #expect(fixture.scheduler.oneOffs.isEmpty)
    }

    @Test func aStopOnAnAbandonedSessionsFollowUpOpensNothing() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, followUp) = try await openSession(fixture)
        fixture.clock.advance(by: 20 * 60 + 1)

        try await loop.ringEnded(systemAlarmID: followUp, via: .stop)

        #expect(try fixture.sessions().count == 1)
        #expect(try await loop.hasOpenSession() == false)
    }

    @Test func theOpeningAlarmRingingAgainInsideTheWindowOfACompletedSessionOpensNothing() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, alarmID, _) = try await openSession(fixture)
        try await loop.recordPhotoCheck(.match)
        fixture.clock.advance(by: 30)

        try await loop.ringEnded(systemAlarmID: alarmID, via: .stop)

        #expect(try fixture.sessions().count == 1)
        #expect(fixture.scheduler.oneOffs.isEmpty)
    }

    @Test func theSameOpeningAlarmADayAfterACompletedSessionOpensANewSession() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, alarmID, _) = try await openSession(fixture)
        try await loop.recordPhotoCheck(.match)
        fixture.clock.advance(by: 24 * 3600)

        try await loop.ringEnded(systemAlarmID: alarmID, via: .stop)

        let sessions = try fixture.sessions()
        #expect(sessions.count == 2)
        #expect(sessions.filter { !$0.isClosed }.count == 1)
        #expect(sessions.last?.firstRingAt == fixture.clock.now)
        #expect(sessions.last?.followUpsArmed == 1)
    }

    // MARK: Mission

    @Test func aMatchCompletesEveryOpenSessionAndCancelsTheirFollowUps() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let loop = fixture.makeLoop()
        try await loop.ringEnded(systemAlarmID: UUID(), via: .stop)
        fixture.clock.advance(by: 300)
        try await loop.ringEnded(systemAlarmID: UUID(), via: .stop)
        let pending = try fixture.sessions().compactMap(\.pendingFollowUpID)
        #expect(pending.count == 2)

        try await loop.recordPhotoCheck(.match)

        let sessions = try fixture.sessions()
        #expect(sessions.count == 2)
        #expect(sessions.allSatisfy { $0.completedAt == fixture.clock.now })
        #expect(sessions.allSatisfy { $0.pendingFollowUpID == nil })
        #expect(Set(fixture.scheduler.cancelled) == Set(pending))
        #expect(fixture.scheduler.oneOffs.isEmpty)
        #expect(try await loop.hasOpenSession() == false)
    }

    @Test func aNoMatchCountsAsAFailedAttemptAndKeepsTheLoopRunning() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, followUp) = try await openSession(fixture)

        try await loop.recordPhotoCheck(.noMatch)

        let session = try #require(try fixture.sessions().first)
        #expect(session.failedChecks == 1)
        #expect(session.pendingFollowUpID == followUp)
        #expect(try await loop.hasOpenSession())
    }

    @Test func fourNoMatchLeaveTheFallbackLocked() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, _) = try await openSession(fixture)

        for _ in 0..<4 { try await loop.recordPhotoCheck(.noMatch) }

        let session = try #require(try fixture.sessions().first)
        #expect(session.failedChecks == 4)
        #expect(session.isFallbackUnlocked == false)
    }

    @Test func fiveNoMatchUnlockTheFallback() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        _ = try await openSessionWithFallbackUnlocked(fixture)

        let session = try #require(try fixture.sessions().first)
        #expect(session.failedChecks == 5)
        #expect(session.isFallbackUnlocked)
    }

    @Test func fifteenCorrectAnswersCompleteTheMission() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let loop = try await openSessionWithFallbackUnlocked(fixture)
        let pending = try #require(try fixture.sessions().first?.pendingFollowUpID)

        for expected in 1...14 {
            let solved = try await loop.recordFallbackAnswer(correct: true)
            #expect(solved == expected)
        }
        #expect(try await loop.hasOpenSession())

        let final = try await loop.recordFallbackAnswer(correct: true)

        #expect(final == 15)
        #expect(try await loop.hasOpenSession() == false)
        let session = try #require(try fixture.sessions().first)
        #expect(session.completedAt == fixture.clock.now)
        #expect(session.pendingFollowUpID == nil)
        #expect(fixture.scheduler.cancelled == [pending])
    }

    @Test func aWrongAnswerResetsTheFallbackToZero() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let loop = try await openSessionWithFallbackUnlocked(fixture)
        for _ in 0..<3 { try await loop.recordFallbackAnswer(correct: true) }
        #expect(try fixture.sessions().first?.fallbackSolved == 3)

        let afterWrong = try await loop.recordFallbackAnswer(correct: false)

        #expect(afterWrong == 0)
        #expect(try fixture.sessions().first?.fallbackSolved == 0)
        #expect(try await loop.hasOpenSession())
    }

    @Test func answersBeforeTheFallbackUnlocksAreIgnored() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, _) = try await openSession(fixture)
        for _ in 0..<4 { try await loop.recordPhotoCheck(.noMatch) }

        let solved = try await loop.recordFallbackAnswer(correct: true)

        #expect(solved == 0)
        #expect(try fixture.sessions().first?.fallbackSolved == 0)
    }

    // MARK: Window

    @Test func aSessionStaysOpenUntilItsWindowCloses() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, _) = try await openSession(fixture)

        fixture.clock.advance(by: 20 * 60 - 1)

        #expect(try await loop.hasOpenSession())
    }

    @Test func theWindowClosingAbandonsTheSessionAndCancelsItsFollowUp() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, followUp) = try await openSession(fixture)
        let firstRingAt = fixture.clock.now

        fixture.clock.advance(by: 20 * 60)

        #expect(try await loop.hasOpenSession() == false)
        let session = try #require(try fixture.sessions().first)
        #expect(session.abandonedAt == firstRingAt.addingTimeInterval(20 * 60))
        #expect(session.completedAt == nil)
        #expect(session.pendingFollowUpID == nil)
        #expect(fixture.scheduler.cancelled == [followUp])
    }

    // MARK: Foreground

    @Test func postponingMovesTheFollowUpToAMinuteFromNowWithoutSpendingTheCap() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, oldFollowUp) = try await openSession(fixture)
        fixture.clock.advance(by: 30)

        try await loop.postponePendingFollowUps()

        let session = try #require(try fixture.sessions().first)
        let replacement = try #require(session.pendingFollowUpID)
        #expect(replacement != oldFollowUp)
        #expect(session.followUpIDs == [oldFollowUp, replacement])
        #expect(session.followUpsArmed == 1)
        #expect(fixture.scheduler.oneOffs == [replacement: fixture.clock.now.addingTimeInterval(60)])
        #expect(fixture.scheduler.cancelled == [oldFollowUp])
    }

    @Test func postponingWithNoOpenSessionSchedulesNothing() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, _) = try await openSession(fixture)
        try await loop.recordPhotoCheck(.match)

        try await loop.postponePendingFollowUps()

        #expect(fixture.scheduler.oneOffs.isEmpty)
    }

    @Test func aFailedPostponementKeepsTheOldFollowUpPending() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, followUp) = try await openSession(fixture)
        fixture.scheduler.schedulingFails = true

        await #expect(throws: FakeAlarmScheduler.SchedulingFailure.self) {
            try await loop.postponePendingFollowUps()
        }

        #expect(try fixture.sessions().first?.pendingFollowUpID == followUp)
        #expect(fixture.scheduler.cancelled.isEmpty)
    }

    @Test func pendingFollowUpsAreReportedForOpenSessionsOnly() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (loop, _, followUp) = try await openSession(fixture)
        #expect(try await loop.pendingFollowUpIDs() == [followUp])

        try await loop.recordPhotoCheck(.match)

        #expect(try await loop.pendingFollowUpIDs().isEmpty)
    }

    // MARK: Persistence

    @Test func aNewLoopOverTheSameStoreSeesTheSameSessionsAndContinuesThem() async throws {
        let fixture = Fixture()
        defer { fixture.cleanUp() }
        let (_, _, followUp) = try await openSession(fixture)
        try await fixture.makeLoop().recordPhotoCheck(.noMatch)

        let freshLoop = fixture.makeLoop()
        let seen = try await freshLoop.openSessions()
        #expect(seen == (try fixture.sessions()))
        #expect(seen.count == 1)
        #expect(seen.first?.failedChecks == 1)
        #expect(seen.first?.pendingFollowUpID == followUp)

        fixture.clock.advance(by: 60)
        try await freshLoop.ringEnded(systemAlarmID: followUp, via: .stop)
        #expect(try fixture.sessions().count == 1)
        #expect(try fixture.sessions().first?.followUpsArmed == 2)
    }
}
