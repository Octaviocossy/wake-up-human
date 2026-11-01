import CoreGraphics
import Foundation
import ImageIO

@testable import PhotoAlarm

/// Scriptable `ObjectMatcher`: every `featurePrint` call returns a distinct `Data("print-<n>")`, and
/// `smallestDistance` returns `nextDistance` while recording the References it was given.
final class FakeObjectMatcher: ObjectMatcher, @unchecked Sendable {
    private let lock = NSLock()
    private var printCount = 0
    private var distance: Float = 0
    private var references: [Data] = []

    var nextDistance: Float {
        get { lock.withLock { distance } }
        set { lock.withLock { distance = newValue } }
    }

    /// The `references` argument of the most recent `smallestDistance` call.
    var lastReferences: [Data] { lock.withLock { references } }

    func featurePrint(of image: CGImage, orientation: CGImagePropertyOrientation) async throws -> Data {
        lock.withLock {
            printCount += 1
            return Data("print-\(printCount)".utf8)
        }
    }

    func smallestDistance(from candidate: Data, toAnyOf references: [Data]) throws -> Float {
        lock.withLock {
            self.references = references
            return distance
        }
    }
}
