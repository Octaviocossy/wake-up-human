import Foundation

/// Mission state as one small JSON file in Application Support. It is read and written on every
/// operation so an alarm-button intent in a freshly launched process sees what the app wrote
/// (product invariant 2). SwiftData is reserved for Alarms and the Target object.
struct MissionStateStore: Sendable {
    let fileURL: URL

    init(directory: URL) {
        fileURL = directory.appending(path: "mission-state.json")
    }

    /// A missing file is an empty state.
    func load() throws -> MissionState {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return MissionState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MissionState.self, from: Data(contentsOf: fileURL))
    }

    /// Drops sessions whose first Ring is older than `MissionPolicy.retention`, then writes atomically.
    func save(_ state: MissionState, now: Date) throws {
        var kept = state
        let oldest = now.addingTimeInterval(-MissionPolicy.retention)
        kept.sessions.removeAll { $0.firstRingAt < oldest }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(kept).write(to: fileURL, options: .atomic)
    }
}
