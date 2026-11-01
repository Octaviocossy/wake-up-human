import CoreGraphics
import Foundation
import ImageIO
import Observation

/// Logic of the mission screen: Photo checks, Fallback answers, and the foreground postponement that keeps
/// the pending Follow-up from ringing while the user is working on the Mission (spec decision 21). The
/// state it shows is read back from the persisted sessions, never held only here (product invariant 2).
@MainActor
@Observable
final class MissionModel {
    private(set) var lastResult: PhotoCheckResult?
    private(set) var lastDistance: Float?
    /// The highest count among the open sessions; a No match counts toward all of them.
    private(set) var failedChecks = 0
    private(set) var isFallbackUnlocked = false
    private(set) var fallbackSolved = 0
    private(set) var isChecking = false
    private(set) var errorMessage: String?

    private let loop: WakeUpLoop
    private let matcher: any ObjectMatcher
    private let repository: TargetObjectRepository
    private let onSessionsClosed: @MainActor () -> Void

    init(
        loop: WakeUpLoop,
        matcher: any ObjectMatcher,
        repository: TargetObjectRepository,
        onSessionsClosed: @escaping @MainActor () -> Void
    ) {
        self.loop = loop
        self.matcher = matcher
        self.repository = repository
        self.onSessionsClosed = onSessionsClosed
    }

    /// Reads the open sessions. With none left (the Mission was completed, or the window closed) it calls
    /// `onSessionsClosed` so the root view can leave the lockdown.
    func refresh() async {
        do {
            let sessions = try await loop.openSessions()
            guard !sessions.isEmpty else {
                onSessionsClosed()
                return
            }
            failedChecks = sessions.map(\.failedChecks).max() ?? 0
            isFallbackUnlocked = sessions.contains(where: \.isFallbackUnlocked)
            fallbackSolved = sessions.map(\.fallbackSolved).max() ?? 0
        } catch {
            Log.mission.error("could not read the sessions: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not read the mission state."
        }
    }

    /// One Photo check on a live camera photo. A matcher error counts as nothing: the error is shown and the
    /// session is left as it was, so a bad photo never feeds the Fallback.
    func check(_ image: CGImage, orientation: CGImagePropertyOrientation) async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }
        do {
            let candidate = try await matcher.featurePrint(of: image, orientation: orientation)
            let references = try repository.referencePrints()
            let distance = try matcher.smallestDistance(from: candidate, toAnyOf: references)
            let result = PhotoCheck.evaluate(distance: distance)
            lastDistance = distance
            lastResult = result
            try await loop.recordPhotoCheck(result)
        } catch ObjectMatcherError.noReferences {
            errorMessage = "No Target object is registered, so there is nothing to match."
        } catch {
            Log.mission.error("photo check failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not check that photo. Try again."
        }
        await refresh()
    }

    /// One Fallback answer; progress is persisted by the loop. `fallbackSolved` is 0 after a wrong one.
    func submitFallbackAnswer(correct: Bool) async {
        do {
            _ = try await loop.recordFallbackAnswer(correct: correct)
        } catch {
            Log.mission.error("could not record the answer: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not save that answer."
        }
        await refresh()
    }

    /// While the mission screen is in the foreground, pushes every pending Follow-up to now + the interval
    /// every `MissionPolicy.postponeTick`. Runs until cancelled; the view cancels it as soon as the app
    /// leaves the foreground, and the last Follow-up then rings within `MissionPolicy.followUpInterval`.
    func runForegroundTicks() async {
        while !Task.isCancelled {
            do {
                try await loop.postponePendingFollowUps()
            } catch {
                Log.mission.error("could not postpone: \(error.localizedDescription, privacy: .public)")
            }
            await refresh()
            do {
                try await Task.sleep(for: .seconds(MissionPolicy.postponeTick))
            } catch {
                return
            }
        }
    }
}
