import CoreGraphics
import Foundation
import ImageIO

enum PhotoCheckResult: Equatable, Sendable {
    case match
    case noMatch
}

enum ObjectMatcherError: Error {
    case noFeaturePrint
    case noReferences
    case corruptFeaturePrint
}

/// Vision sits behind this protocol so setup and mission logic are tested with a fake.
protocol ObjectMatcher: Sendable {
    /// Archived feature print of one live camera photo.
    func featurePrint(of image: CGImage, orientation: CGImagePropertyOrientation) async throws -> Data
    /// Smallest distance from `candidate` to any of `references`.
    func smallestDistance(from candidate: Data, toAnyOf references: [Data]) throws -> Float
}

enum PhotoCheck {
    static func evaluate(distance: Float, threshold: Float = MatchThreshold.value) -> PhotoCheckResult {
        distance < threshold ? .match : .noMatch
    }
}
