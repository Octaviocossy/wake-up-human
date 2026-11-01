import CoreGraphics
import Foundation
import ImageIO
import Observation

/// State machine of the Object setup screen: 3 to 5 References, then a test photo that must pass
/// before the Target object is registered (spec decision 7).
@MainActor
@Observable
final class ObjectSetupModel {
    enum Phase: Equatable {
        case capturing
        case testing
        case testFailed(distance: Float)
        case registered
    }

    static let minReferences = 3
    static let maxReferences = 5

    private(set) var phase: Phase = .capturing
    private(set) var capturedPrints: [Data] = []
    private(set) var errorMessage: String?
    /// Distance of the most recent test photo, shown on both a pass and a failure.
    private(set) var lastTestDistance: Float?

    var canCaptureMore: Bool { phase == .capturing && capturedPrints.count < Self.maxReferences }
    var canStartTest: Bool { phase == .capturing && capturedPrints.count >= Self.minReferences }

    private let matcher: any ObjectMatcher
    private let repository: TargetObjectRepository
    private let now: () -> Date

    init(
        matcher: any ObjectMatcher,
        repository: TargetObjectRepository,
        now: @escaping () -> Date = { .now }
    ) {
        self.matcher = matcher
        self.repository = repository
        self.now = now
    }

    /// Adds one Reference from a live camera photo. Ignored past `maxReferences` or outside `.capturing`.
    func addReference(_ image: CGImage, orientation: CGImagePropertyOrientation) async {
        guard canCaptureMore else { return }
        errorMessage = nil
        do {
            let print = try await matcher.featurePrint(of: image, orientation: orientation)
            // The phase may have moved on while Vision ran; re-check before appending.
            guard canCaptureMore else { return }
            capturedPrints.append(print)
        } catch {
            errorMessage = "Could not read that photo. Try again with the object filling more of the frame."
        }
    }

    func startTest() {
        guard canStartTest else { return }
        errorMessage = nil
        phase = .testing
    }

    /// Compares the test photo against the **new** References (not the previous object's). Only a
    /// passing photo persists anything; a failing one leaves any previously registered object alone.
    func submitTestPhoto(_ image: CGImage, orientation: CGImagePropertyOrientation) async {
        guard phase == .testing else { return }
        errorMessage = nil
        do {
            let testPrint = try await matcher.featurePrint(of: image, orientation: orientation)
            let distance = try matcher.smallestDistance(from: testPrint, toAnyOf: capturedPrints)
            lastTestDistance = distance
            switch PhotoCheck.evaluate(distance: distance) {
            case .match:
                try repository.replace(with: capturedPrints, testPassedAt: now())
                phase = .registered
            case .noMatch:
                phase = .testFailed(distance: distance)
            }
        } catch {
            errorMessage = "Could not check that photo. Try again."
        }
    }

    func retryTest() {
        guard case .testFailed = phase else { return }
        errorMessage = nil
        phase = .testing
    }

    /// Discards the captured References and starts over. A registered object is untouched until a
    /// new test photo passes.
    func restart() {
        capturedPrints = []
        errorMessage = nil
        lastTestDistance = nil
        phase = .capturing
    }
}
