import CoreGraphics
import Foundation
import SwiftData
import Testing

@testable import PhotoAlarm

@MainActor
struct ObjectSetupModelTests {
    /// Owns the container so the context stays valid for the whole test.
    @MainActor
    private struct Fixture {
        let container: ModelContainer
        let repository: TargetObjectRepository
        let matcher: FakeObjectMatcher

        init(matcher: FakeObjectMatcher = FakeObjectMatcher()) throws {
            container = try AppModelContainer.make(inMemory: true)
            repository = TargetObjectRepository(context: container.mainContext)
            self.matcher = matcher
        }

        func makeModel() -> ObjectSetupModel {
            ObjectSetupModel(
                matcher: matcher, repository: repository, now: { Date(timeIntervalSince1970: 1_000) })
        }

        func objectCount() throws -> Int {
            try container.mainContext.fetchCount(FetchDescriptor<TargetObject>())
        }

        func referenceCount() throws -> Int {
            try container.mainContext.fetchCount(FetchDescriptor<ReferencePrint>())
        }
    }

    private func capture(_ count: Int, into model: ObjectSetupModel) async {
        for _ in 0..<count {
            await model.addReference(TestImages.onePixel(), orientation: .up)
        }
    }

    private func register(with model: ObjectSetupModel, fixture: Fixture) async {
        await capture(3, into: model)
        model.startTest()
        fixture.matcher.nextDistance = 0.1
        await model.submitTestPhoto(TestImages.onePixel(), orientation: .up)
    }

    @Test func twoReferencesCannotStartTheTest() async throws {
        let fixture = try Fixture()
        let model = fixture.makeModel()
        await capture(2, into: model)
        #expect(model.canStartTest == false)
        model.startTest()
        #expect(model.phase == .capturing)
    }

    @Test func threeReferencesCanStartTheTest() async throws {
        let fixture = try Fixture()
        let model = fixture.makeModel()
        await capture(3, into: model)
        #expect(model.canStartTest)
        model.startTest()
        #expect(model.phase == .testing)
    }

    @Test func sixthReferenceIsIgnored() async throws {
        let fixture = try Fixture()
        let model = fixture.makeModel()
        await capture(6, into: model)
        #expect(model.capturedPrints.count == ObjectSetupModel.maxReferences)
        #expect(model.canCaptureMore == false)
    }

    @Test func failedTestPersistsNothing() async throws {
        let fixture = try Fixture()
        let model = fixture.makeModel()
        await capture(3, into: model)
        model.startTest()
        fixture.matcher.nextDistance = 0.9
        await model.submitTestPhoto(TestImages.onePixel(), orientation: .up)
        #expect(model.phase == .testFailed(distance: 0.9))
        #expect(try fixture.objectCount() == 0)
        #expect(try fixture.repository.isRegistered() == false)
    }

    @Test func failedTestKeepsThePreviouslyRegisteredObject() async throws {
        let fixture = try Fixture()
        let first = fixture.makeModel()
        await register(with: first, fixture: fixture)
        let registeredPrints = try fixture.repository.referencePrints()

        let second = fixture.makeModel()
        await capture(3, into: second)
        second.startTest()
        fixture.matcher.nextDistance = 0.9
        await second.submitTestPhoto(TestImages.onePixel(), orientation: .up)

        #expect(second.phase == .testFailed(distance: 0.9))
        #expect(try fixture.objectCount() == 1)
        #expect(try fixture.repository.referencePrints() == registeredPrints)
    }

    @Test func testPhotoIsComparedAgainstTheNewReferencesOnly() async throws {
        let fixture = try Fixture()
        await register(with: fixture.makeModel(), fixture: fixture)

        let second = fixture.makeModel()
        await capture(3, into: second)
        second.startTest()
        await second.submitTestPhoto(TestImages.onePixel(), orientation: .up)

        #expect(fixture.matcher.lastReferences == second.capturedPrints)
    }

    @Test func passingTestLeavesOneObjectWithTheNewPrints() async throws {
        let fixture = try Fixture()
        let model = fixture.makeModel()
        await register(with: model, fixture: fixture)

        #expect(model.phase == .registered)
        #expect(try fixture.objectCount() == 1)
        #expect(try fixture.repository.referencePrints() == model.capturedPrints)
    }

    @Test func registeringTwiceStillLeavesExactlyOneObject() async throws {
        let fixture = try Fixture()
        await register(with: fixture.makeModel(), fixture: fixture)
        let second = fixture.makeModel()
        await register(with: second, fixture: fixture)

        #expect(try fixture.objectCount() == 1)
        #expect(try fixture.referenceCount() == 3)
        #expect(try fixture.repository.referencePrints() == second.capturedPrints)
    }

    @Test func retryAfterAFailedTestReturnsToTesting() async throws {
        let fixture = try Fixture()
        let model = fixture.makeModel()
        await capture(3, into: model)
        model.startTest()
        fixture.matcher.nextDistance = 0.9
        await model.submitTestPhoto(TestImages.onePixel(), orientation: .up)
        model.retryTest()
        #expect(model.phase == .testing)
    }

    @Test func restartClearsTheCapturedReferences() async throws {
        let fixture = try Fixture()
        let model = fixture.makeModel()
        await capture(4, into: model)
        model.restart()
        #expect(model.capturedPrints.isEmpty)
        #expect(model.phase == .capturing)
    }
}
