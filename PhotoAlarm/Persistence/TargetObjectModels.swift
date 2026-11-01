import Foundation
import SwiftData

@Model
final class TargetObject {
    var registeredAt: Date
    var testPassedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ReferencePrint.object) var references: [ReferencePrint] = []

    init(registeredAt: Date, testPassedAt: Date) {
        self.registeredAt = registeredAt
        self.testPassedAt = testPassedAt
    }
}

@Model
final class ReferencePrint {
    var featurePrint: Data
    var capturedAt: Date
    var object: TargetObject?

    init(featurePrint: Data, capturedAt: Date) {
        self.featurePrint = featurePrint
        self.capturedAt = capturedAt
    }
}
