import Foundation
import SwiftData

@MainActor
struct TargetObjectRepository {
    let context: ModelContext

    func current() throws -> TargetObject? {
        try context.fetch(FetchDescriptor<TargetObject>()).first
    }

    func isRegistered() throws -> Bool {
        try current() != nil
    }

    func referencePrints() throws -> [Data] {
        try current()?.references.map(\.featurePrint) ?? []
    }

    /// Exactly one Target object: deletes any existing one (cascading its References), then inserts the new one.
    func replace(with prints: [Data], testPassedAt: Date) throws {
        for object in try context.fetch(FetchDescriptor<TargetObject>()) {
            context.delete(object)
        }
        let object = TargetObject(registeredAt: testPassedAt, testPassedAt: testPassedAt)
        context.insert(object)
        object.references = prints.map { ReferencePrint(featurePrint: $0, capturedAt: testPassedAt) }
        try context.save()
    }
}
