#if DEBUG
    import AlarmKit
    import SwiftUI

    /// M1 spike: proves the Ring sounds in every device state, that a stopped Ring comes back about a
    /// minute later, and records which dismissals actually run an alarm-button intent. Operable on the
    /// phone without Xcode attached; results go into `docs/alarmkit-findings.md`.
    struct AlarmSpikeView: View {
        private let scheduler: any AlarmScheduler = AlarmKitScheduler()

        @State private var authorization = AlarmManager.shared.authorizationState
        @State private var systemAlarms: [ScheduledSystemAlarm] = []
        @State private var events: [IntentEvent] = []
        @State private var postponeEnabled = false
        @State private var errorMessage: String?

        var body: some View {
            List {
                authorizationSection
                ringTestsSection
                postponeSection
                systemAlarmsSection
                intentEventsSection
            }
            .navigationTitle("AlarmKit spike")
            .task { await refresh() }
            .task(id: postponeEnabled) { await runPostponeTest() }
            .onDisappear { postponeEnabled = false }
            .alert("AlarmKit error", isPresented: showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }

        // MARK: Sections

        private var authorizationSection: some View {
            Section("Authorization") {
                LabeledContent("AlarmKit", value: Self.label(for: authorization))
                Button("Request authorization") {
                    Task {
                        _ = await scheduler.requestAuthorization()
                        await refresh()
                    }
                }
            }
        }

        private var ringTestsSection: some View {
            Section {
                Button("Alarm in 1 minute") {
                    Task {
                        await run { try await scheduler.scheduleOneOff(id: UUID(), at: .now.addingTimeInterval(60)) }
                    }
                }
                Button("Weekly alarm in 2 minutes") {
                    Task { await run(scheduleWeeklyInTwoMinutes) }
                }
            } header: {
                Text("Ring tests")
            } footer: {
                Text(
                    "Stop and Take photo each open a Wake-up session and arm a Follow-up 60 s out, up to the cap, "
                        + "through the real re-alarm loop. A Match or the Fallback ends it. "
                        + "The weekly alarm repeats every week until cancelled.")
            }
        }

        private var postponeSection: some View {
            Section {
                Toggle("Keep postponing a one-off", isOn: $postponeEnabled)
            } header: {
                Text("Postpone test")
            } footer: {
                Text(
                    "While on and this screen is visible, a one-off 60 s out is replaced every 30 s, so it should "
                        + "never ring. It should ring within 60 s of locking the phone or leaving this screen.")
            }
        }

        private var systemAlarmsSection: some View {
            Section("Scheduled System alarms") {
                if systemAlarms.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                }
                ForEach(systemAlarms, id: \.id) { alarm in
                    LabeledContent(Self.shortID(alarm.id), value: Self.label(for: alarm.state))
                }
                Button("Refresh") { Task { await refresh() } }
                Button("Cancel all", role: .destructive) { cancelAll() }
                    .disabled(systemAlarms.isEmpty)
            }
        }

        private var intentEventsSection: some View {
            Section("Intent events") {
                if events.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                }
                ForEach(events) { event in
                    LabeledContent(
                        "\(event.date.formatted(date: .omitted, time: .standard)) \(event.kind.rawValue)",
                        value: Self.shortID(event.alarmID))
                }
                Button("Clear log", role: .destructive) {
                    Task {
                        await IntentEventLog.shared.clear()
                        await refresh()
                    }
                }
            }
        }

        // MARK: Actions

        private var showingError: Binding<Bool> {
            Binding(
                get: { errorMessage != nil },
                set: { isShowing in if !isShowing { errorMessage = nil } })
        }

        /// Runs an AlarmKit action after making sure it is authorized; a thrown error is shown, never fatal.
        private func run(_ action: () async throws -> Void) async {
            guard await scheduler.requestAuthorization() else {
                errorMessage = "AlarmKit is not authorized."
                await refresh()
                return
            }
            do {
                try await action()
            } catch {
                report(error)
            }
            await refresh()
        }

        private func scheduleWeeklyInTwoMinutes() async throws {
            let target = Date.now.addingTimeInterval(120)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let parts = calendar.dateComponents([.weekday, .hour, .minute], from: target)
            guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return }
            try await scheduler.scheduleWeekly(
                id: UUID(), hour: hour, minute: minute, weekdays: [Self.weekdays[weekday - 1]])
        }

        private func cancelAll() {
            var firstError: Error?
            for alarm in systemAlarms {
                do {
                    try scheduler.cancel(id: alarm.id)
                } catch {
                    firstError = firstError ?? error
                }
            }
            if let firstError { report(firstError) }
            Task { await refresh() }
        }

        private func refresh() async {
            authorization = AlarmManager.shared.authorizationState
            do {
                systemAlarms = try scheduler.scheduledAlarms()
            } catch {
                report(error)
            }
            let logged = (try? await IntentEventLog.shared.load()) ?? []
            events = logged.sorted { $0.date > $1.date }
        }

        /// Replaces a one-off 60 s out every 30 s for as long as the screen is visible and the toggle is on.
        /// The new alarm is scheduled before the old one is cancelled, so being suspended between the two
        /// calls never leaves the phone with no alarm. When the task ends (screen left, toggle off) the last
        /// one-off stays scheduled and rings within 60 s.
        private func runPostponeTest() async {
            guard postponeEnabled else { return }
            guard await scheduler.requestAuthorization() else {
                errorMessage = "AlarmKit is not authorized."
                postponeEnabled = false
                return
            }
            var current: UUID?
            do {
                while !Task.isCancelled {
                    let next = UUID()
                    try await scheduler.scheduleOneOff(id: next, at: .now.addingTimeInterval(60))
                    Log.alarm.info("postpone test: scheduled \(next.uuidString, privacy: .public)")
                    if let previous = current {
                        try scheduler.cancel(id: previous)
                        Log.alarm.info("postpone test: cancelled \(previous.uuidString, privacy: .public)")
                    }
                    current = next
                    await refresh()
                    try await Task.sleep(for: .seconds(30))
                }
            } catch is CancellationError {
                Log.alarm.info("postpone test: ended, last one-off stays scheduled")
            } catch {
                report(error)
                postponeEnabled = false
            }
        }

        private func report(_ error: Error) {
            Log.alarm.error("alarm spike error: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }

        // MARK: Formatting

        private static let weekdays: [Locale.Weekday] = [
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
        ]

        private static func shortID(_ id: UUID) -> String {
            String(id.uuidString.prefix(8))
        }

        private static func label(for state: AlarmManager.AuthorizationState) -> String {
            switch state {
            case .notDetermined: "not determined"
            case .denied: "denied"
            case .authorized: "authorized"
            @unknown default: "unknown"
            }
        }

        private static func label(for state: ScheduledSystemAlarm.State) -> String {
            switch state {
            case .scheduled: "scheduled"
            case .alerting: "alerting"
            case .other: "other"
            }
        }
    }
#endif
