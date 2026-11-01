import Foundation
import SwiftData
import Testing

@testable import PhotoAlarm

@MainActor
struct MissionModelTests {
    @MainActor
    private final class ClosedCounter {
        var count = 0
    }

    /// Owns the container so the repository's context stays valid for the whole test.
    @MainActor
    private struct Fixture {
        let container: ModelContainer
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let clock = TestClock()
        let scheduler = FakeAlarmScheduler()
        let matcher = FakeObjectMatcher()
        let closed = ClosedCounter()
        let loop: WakeUpLoop
        let model: MissionModel

        init() throws {
            container = try AppModelContainer.make(inMemory: true)
            let repository = TargetObjectRepository(context: container.mainContext)
            try repository.replace(with: [Data("reference".utf8)], testPassedAt: Date(timeIntervalSince1970: 1))
            let clock = self.clock
            loop = WakeUpLoop(
                store: MissionStateStore(directory: directory), scheduler: scheduler, now: { clock.now })
            let closed = self.closed
            model = MissionModel(
                loop: loop, matcher: matcher, repository: repository, onSessionsClosed: { closed.count += 1 })
        }

        func openSession() async throws {
            try await loop.ringEnded(systemAlarmID: UUID(), via: .stop)
            await model.refresh()
        }

        func photoCheck() async {
            await model.check(TestImages.onePixel(), orientation: .up)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    @Test func aMatchCompletesTheMissionAndTellsTheScreenToLeave() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try await fixture.openSession()
        fixture.matcher.nextDistance = 0.1

        await fixture.photoCheck()

        #expect(fixture.model.lastResult == .match)
        #expect(fixture.model.lastDistance == 0.1)
        #expect(try await fixture.loop.hasOpenSession() == false)
        #expect(fixture.closed.count == 1)
        #expect(fixture.matcher.lastReferences == [Data("reference".utf8)])
    }

    @Test func aNoMatchIsAFailedAttemptAndTheSessionStaysOpen() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try await fixture.openSession()
        fixture.matcher.nextDistance = 0.9

        await fixture.photoCheck()

        #expect(fixture.model.lastResult == .noMatch)
        #expect(fixture.model.failedChecks == 1)
        #expect(fixture.model.isFallbackUnlocked == false)
        #expect(try await fixture.loop.hasOpenSession())
        #expect(fixture.closed.count == 0)
    }

    @Test func fiveNoMatchUnlockTheFallbackOnTheScreen() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try await fixture.openSession()
        fixture.matcher.nextDistance = 0.9

        for _ in 0..<5 { await fixture.photoCheck() }

        #expect(fixture.model.failedChecks == 5)
        #expect(fixture.model.isFallbackUnlocked)
    }

    @Test func fifteenCorrectFallbackAnswersEndTheMission() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try await fixture.openSession()
        fixture.matcher.nextDistance = 0.9
        for _ in 0..<5 { await fixture.photoCheck() }

        for expected in 1...14 {
            await fixture.model.submitFallbackAnswer(correct: true)
            #expect(fixture.model.fallbackSolved == expected)
        }
        await fixture.model.submitFallbackAnswer(correct: false)
        #expect(fixture.model.fallbackSolved == 0)
        for _ in 0..<15 { await fixture.model.submitFallbackAnswer(correct: true) }

        #expect(try await fixture.loop.hasOpenSession() == false)
        #expect(fixture.closed.count >= 1)
    }

    @Test func refreshWithNoOpenSessionTellsTheScreenToLeave() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        await fixture.model.refresh()

        #expect(fixture.closed.count == 1)
    }
}
