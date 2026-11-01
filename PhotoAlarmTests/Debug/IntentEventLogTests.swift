#if DEBUG
    import Foundation
    import Testing

    @testable import PhotoAlarm

    struct IntentEventLogTests {
        /// A unique directory that does not exist yet, so the first append also covers creating it.
        private func makeDirectory() -> URL {
            FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        }

        private func makeEvent(_ kind: IntentEvent.Kind, at seconds: TimeInterval) -> IntentEvent {
            IntentEvent(kind: kind, alarmID: UUID(), date: Date(timeIntervalSinceReferenceDate: seconds))
        }

        @Test func appendedEventsLoadInOrder() async throws {
            let directory = makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let log = IntentEventLog(directory: directory)
            let first = makeEvent(.stop, at: 1_000)
            let second = makeEvent(.openMission, at: 2_000)

            await log.append(first)
            await log.append(second)

            #expect(try await log.load() == [first, second])
        }

        @Test func eventsSurviveANewLogOnTheSameDirectory() async throws {
            let directory = makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let event = makeEvent(.followUpArmed, at: 3_000)

            await IntentEventLog(directory: directory).append(event)

            #expect(try await IntentEventLog(directory: directory).load() == [event])
        }

        @Test func clearEmptiesTheLog() async throws {
            let directory = makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let log = IntentEventLog(directory: directory)
            await log.append(makeEvent(.stop, at: 1_000))

            await log.clear()

            #expect(try await log.load().isEmpty)
        }

        @Test func loadingAMissingFileReturnsNoEvents() async throws {
            let directory = makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            #expect(try await IntentEventLog(directory: directory).load().isEmpty)
        }
    }
#endif
