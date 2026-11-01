#if DEBUG
    import Foundation

    /// Spike for spec decision 31. Run the built app with `-volumeProbe`: it nudges the default
    /// output device's volume by 0.01 and back (inaudible), prints whether each write took effect and
    /// whether the process is sandboxed, and exits — 0 if the write took effect, 1 otherwise.
    enum VolumeProbe {
        /// The smallest nudge is tried first; a device that quantizes its volume (many Bluetooth
        /// speakers move in 1/16 steps) swallows it, so a wider one follows before the probe concludes.
        private static let nudges: [Float32] = [0.01, 0.07]

        @MainActor
        static func runIfRequested() {
            guard CommandLine.arguments.contains("-volumeProbe") else { return }
            exit(run() ? 0 : 1)
        }

        @MainActor
        private static func run() -> Bool {
            let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
            output("sandboxed: \(sandboxed ? "yes" : "no")")

            let volume = CoreAudioSystemVolume()
            guard let before = volume.current() else {
                output("device: (none)")
                output("write-took-effect: no — the default output device has no settable volume")
                return false
            }
            output("device: \(before.deviceUID)")
            output("before: \(before.volume)")

            var tookEffect = false
            for nudge in nudges {
                let target = before.volume >= nudge ? before.volume - nudge : before.volume + nudge
                let accepted = volume.setVolume(target)
                let readBack = volume.current()?.volume
                output("write \(target): accepted \(accepted ? "yes" : "no"), after-write: \(describe(readBack))")
                // Put the level back before judging anything else.
                volume.setVolume(before.volume)
                if let readBack, abs(readBack - target) < 0.005 {
                    tookEffect = true
                    break
                }
            }

            output("after-restore: \(describe(volume.current()?.volume))")
            // Informational only: writes the mute state it just read back to itself, which is inaudible.
            // "no" means the device has no mute control or the write was refused.
            output(
                "mute-write (no-op, muted=\(before.isMuted)): accepted \(volume.setMuted(before.isMuted) ? "yes" : "no")"
            )
            output("write-took-effect: \(tookEffect ? "yes" : "no")")
            return tookEffect
        }

        private static func describe(_ level: Float32?) -> String {
            guard let level else { return "(unreadable)" }
            return String(level)
        }

        private static func output(_ line: String) {
            print(line)
            fflush(stdout)
        }
    }
#endif
