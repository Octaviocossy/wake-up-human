#if DEBUG
    import Foundation

    /// The spike's stand-in for the re-alarm loop: each alarm-button intent arms a one-off Follow-up
    /// about a minute out, at most `maxFollowUps` times, so the loop can be tested on the device without
    /// risking a runaway alarm. The mission child replaces this with the session-aware loop.
    enum SpikeFollowUp {
        static let maxFollowUps = 3
        static let interval: TimeInterval = 60

        private static let counterKey = "spike.followUpsArmed"

        /// Follow-ups armed since the last reset.
        static var armedCount: Int { UserDefaults.standard.integer(forKey: counterKey) }

        static func resetCounter() {
            UserDefaults.standard.set(0, forKey: counterKey)
        }

        /// What both alarm-button intents do in a Debug build: log the invocation, then arm a Follow-up.
        static func record(_ kind: IntentEvent.Kind, alarmID: UUID) async {
            await IntentEventLog.shared.append(IntentEvent(kind: kind, alarmID: alarmID, date: .now))
            do {
                try await armIfAllowed()
            } catch {
                Log.alarm.error("spike follow-up failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        static func armIfAllowed(scheduler: some AlarmScheduler = AlarmKitScheduler()) async throws {
            let armed = armedCount
            guard armed < maxFollowUps else {
                Log.alarm.info("spike follow-up cap reached")
                return
            }
            let id = UUID()
            try await scheduler.scheduleOneOff(id: id, at: .now.addingTimeInterval(interval))
            UserDefaults.standard.set(armed + 1, forKey: counterKey)
            await IntentEventLog.shared.append(IntentEvent(kind: .followUpArmed, alarmID: id, date: .now))
        }
    }
#endif
