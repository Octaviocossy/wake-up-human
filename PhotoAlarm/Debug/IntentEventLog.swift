#if DEBUG
    import Foundation

    /// One alarm-button intent invocation (or a Follow-up the spike armed), kept so the spike screen
    /// can show which dismissals actually ran an intent on the device.
    struct IntentEvent: Codable, Equatable, Sendable, Identifiable {
        enum Kind: String, Codable, Sendable { case stop, openMission, followUpArmed }

        var id = UUID()
        let kind: Kind
        let alarmID: UUID
        let date: Date
    }

    /// Persisted to a JSON file because the intents run in short bursts, possibly in a freshly launched
    /// process, and the log must survive them.
    actor IntentEventLog {
        static let shared = IntentEventLog(directory: .applicationSupportDirectory)

        private let fileURL: URL

        init(directory: URL) {
            fileURL = directory.appending(path: "intent-events.json")
        }

        func append(_ event: IntentEvent) {
            var events = (try? load()) ?? []
            events.append(event)
            try? save(events)
        }

        func load() throws -> [IntentEvent] {
            guard FileManager.default.fileExists(atPath: fileURL.path()) else { return [] }
            return try JSONDecoder().decode([IntentEvent].self, from: Data(contentsOf: fileURL))
        }

        func clear() {
            try? FileManager.default.removeItem(at: fileURL)
        }

        private func save(_ events: [IntentEvent]) throws {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(events).write(to: fileURL, options: .atomic)
        }
    }
#endif
