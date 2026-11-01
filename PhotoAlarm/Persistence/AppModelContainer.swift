import SwiftData

enum AppModelContainer {
    /// The single schema list. Later children append their models here.
    static var schema: Schema { Schema([TargetObject.self, ReferencePrint.self]) }

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
    }
}
