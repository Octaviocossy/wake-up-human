import Foundation

extension Notification.Name {
    /// Posted on the main actor whenever a Wake-up session was opened, changed or closed, so the root
    /// view can re-check whether the mission lockdown applies (an intent may finish after the first check).
    static let wakeUpSessionsChanged = Notification.Name("wakeUpSessionsChanged")
}

/// The session-aware re-alarm loop (ADR-0025). Only the two alarm-button intents arm a Follow-up, through
/// `ringEnded`; only a completed Mission cancels it. Nothing is pre-scheduled, and nothing runs in the
/// background: an expired session is abandoned lazily, the next time any method here runs.
///
/// Every operation loads the state from `MissionStateStore`, changes it and saves it back, so an intent in a
/// fresh process sees what the app wrote (product invariant 2). Operations run one at a time, even across
/// the `await` on the scheduler, so two of them never save over each other.
actor WakeUpLoop {
    private let store: MissionStateStore
    private let scheduler: any AlarmScheduler
    private let now: @Sendable () -> Date

    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(
        store: MissionStateStore,
        scheduler: any AlarmScheduler,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.scheduler = scheduler
        self.now = now
    }

    // MARK: Ring

    /// Both alarm-button intents call this after a Ring ends. It finds the Wake-up session the Ring belongs
    /// to (or opens one) and arms that session's next Follow-up. Stop and "Take photo" behave identically.
    func ringEnded(systemAlarmID: UUID, via exit: RingExit) async throws {
        try await transact { state, current in
            // A Follow-up of any session, then the opening alarm of a session still inside its window;
            // anything else is the first Ring of a new occurrence (a completed session never covers a later one).
            let index: Int
            if let found = state.sessions.lastIndex(where: { $0.followUpIDs.contains(systemAlarmID) })
                ?? state.sessions.lastIndex(where: { $0.openingAlarmID == systemAlarmID && current < $0.windowEnd })
            {
                index = found
            } else {
                state.sessions.append(
                    WakeUpSession(id: UUID(), openingAlarmID: systemAlarmID, firstRingAt: current))
                index = state.sessions.count - 1
                Log.mission.info("opened session for \(systemAlarmID.uuidString, privacy: .public)")
            }

            // A stale Follow-up never opens a session, and a closed one is never revived.
            guard !state.sessions[index].isClosed else {
                Log.mission.info("ring \(systemAlarmID.uuidString, privacy: .public) belongs to a closed session")
                return
            }

            if state.sessions[index].pendingFollowUpID == systemAlarmID {
                state.sessions[index].pendingFollowUpID = nil
            }
            guard
                state.sessions[index].followUpsArmed < MissionPolicy.followUpCap,
                state.sessions[index].pendingFollowUpID == nil
            else { return }

            // Schedule first, then save: if saving fails the Follow-up still rings.
            let followUpID = UUID()
            try await scheduler.scheduleOneOff(
                id: followUpID, at: current.addingTimeInterval(MissionPolicy.followUpInterval))
            state.sessions[index].followUpIDs.append(followUpID)
            state.sessions[index].pendingFollowUpID = followUpID
            state.sessions[index].followUpsArmed += 1
            let armed = state.sessions[index].followUpsArmed
            Log.mission.info("armed follow-up \(armed) via \(exit.rawValue, privacy: .public)")
        }
    }

    // MARK: Reads

    /// Sessions that are neither completed nor abandoned.
    func openSessions() async throws -> [WakeUpSession] {
        try await transact { state, _ in state.sessions.filter { !$0.isClosed } }
    }

    func hasOpenSession() async throws -> Bool {
        try await !openSessions().isEmpty
    }

    /// System alarms that belong to open sessions; the alarm sync must not touch them.
    func pendingFollowUpIDs() async throws -> Set<UUID> {
        try await transact { state, _ in
            Set(state.sessions.filter { !$0.isClosed }.compactMap(\.pendingFollowUpID))
        }
    }

    // MARK: Mission

    /// A Match completes the Mission; a No match is one failed attempt toward the Fallback.
    func recordPhotoCheck(_ result: PhotoCheckResult) async throws {
        try await transact { state, current in
            switch result {
            case .match:
                completeMission(in: &state, at: current)
            case .noMatch:
                for index in state.sessions.indices where !state.sessions[index].isClosed {
                    state.sessions[index].failedChecks += 1
                }
            }
        }
    }

    /// Records one Fallback answer and returns the solved count after it (0 after a wrong one). Ignored
    /// until some open session has unlocked the Fallback. The 15th correct answer completes the Mission
    /// exactly like a Match.
    @discardableResult
    func recordFallbackAnswer(correct: Bool) async throws -> Int {
        try await transact { state, current in
            let open = state.sessions.indices.filter { !state.sessions[$0].isClosed }
            guard open.contains(where: { state.sessions[$0].isFallbackUnlocked }) else {
                return open.map { state.sessions[$0].fallbackSolved }.max() ?? 0
            }
            for index in open {
                state.sessions[index].fallbackSolved = correct ? state.sessions[index].fallbackSolved + 1 : 0
            }
            let solved = open.map { state.sessions[$0].fallbackSolved }.max() ?? 0
            if solved >= MissionPolicy.fallbackProblemCount {
                completeMission(in: &state, at: current)
            }
            return solved
        }
    }

    // MARK: Foreground

    /// The mission screen is in the foreground: push every pending Follow-up to now + the interval, so it
    /// rings only once the user leaves. The replacement is scheduled before the old one is cancelled, so
    /// being suspended in between never leaves a session with no Follow-up. Does not consume the cap.
    func postponePendingFollowUps() async throws {
        try await transact { state, current in
            var firstError: (any Error)?
            for index in state.sessions.indices {
                guard !state.sessions[index].isClosed, let old = state.sessions[index].pendingFollowUpID else {
                    continue
                }
                let replacement = UUID()
                do {
                    try await scheduler.scheduleOneOff(
                        id: replacement, at: current.addingTimeInterval(MissionPolicy.followUpInterval))
                } catch {
                    // The old Follow-up stays pending and still rings: the failure mode is an extra Ring.
                    firstError = firstError ?? error
                    continue
                }
                try? scheduler.cancel(id: old)
                state.sessions[index].followUpIDs.append(replacement)
                state.sessions[index].pendingFollowUpID = replacement
            }
            if let firstError { throw firstError }
        }
    }

    // MARK: State handling

    /// Completes every open session: a Match, or a completed Fallback, ends all of them at once.
    private func completeMission(in state: inout MissionState, at current: Date) {
        for index in state.sessions.indices where !state.sessions[index].isClosed {
            if let pending = state.sessions[index].pendingFollowUpID {
                try? scheduler.cancel(id: pending)
            }
            state.sessions[index].pendingFollowUpID = nil
            state.sessions[index].completedAt = current
            let sessionID = state.sessions[index].id
            Log.mission.info("completed session \(sessionID.uuidString, privacy: .public)")
        }
    }

    /// Abandons every open session whose Follow-up window has closed, at the instant it closed.
    private func abandonExpiredSessions(in state: inout MissionState, at current: Date) {
        for index in state.sessions.indices {
            let session = state.sessions[index]
            guard !session.isClosed, current >= session.windowEnd else { continue }
            if let pending = session.pendingFollowUpID {
                try? scheduler.cancel(id: pending)
            }
            state.sessions[index].pendingFollowUpID = nil
            state.sessions[index].abandonedAt = session.windowEnd
            Log.mission.info("abandoned session \(session.id.uuidString, privacy: .public)")
        }
    }

    /// Load → abandon expired sessions → `body` → save, one operation at a time. The state is saved even
    /// when `body` throws, so whatever it achieved before failing is not forgotten; the error is then rethrown.
    /// Saving and posting happen only when something changed, so reading never triggers a notification.
    private func transact<T>(_ body: (inout MissionState, Date) async throws -> T) async throws -> T {
        await acquire()
        defer { release() }

        let stored = try store.load()
        let current = now()
        var state = stored
        abandonExpiredSessions(in: &state, at: current)

        let outcome: Result<T, any Error>
        do {
            outcome = .success(try await body(&state, current))
        } catch {
            outcome = .failure(error)
        }

        if state != stored {
            try store.save(state, now: current)
            Task { @MainActor in NotificationCenter.default.post(name: .wakeUpSessionsChanged, object: nil) }
        }
        return try outcome.get()
    }

    private func acquire() async {
        if isBusy {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            isBusy = true
        }
    }

    private func release() {
        if waiters.isEmpty {
            isBusy = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
