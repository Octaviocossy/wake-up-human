# Spec: Wake Up Human — macOS menu-bar alarm dismissed by typing

> Status: **settled**
> Created: 2026-11-01
> Grilled: 2026-11-01 — 4 rounds, 33 decisions; reconciled with the prototype the same day
> (decisions 5, 25, 32, 33 amended; 34–38 added)
> Suggested next: /spec-breakdown
> Supersedes: `.agents/specs/2026-10-31-photo-alarm-mvp.md` (the iOS Photo Alarm, retired)
> Design reference: `docs/design/` (decision 34)

## Goal

Pivot Wake Up Human from the iOS photo alarm to a macOS menu-bar app: the Mac stays on overnight
with a Bluetooth speaker connected, an Alarm is silenced only by typing text shown on screen, and
an optional Bedtime mode plays soft rain while the user falls asleep. Kept deliberately simple,
reusing the patterns of the sibling app Caffeinassy.

## Settled Decisions

| # | Decision | Chosen | Rationale |
|---|----------|--------|-----------|
| 1 | Where the macOS app lives | This repo, from scratch. The first slice deletes `PhotoAlarm/`, `PhotoAlarmTests/`, `Config/`, the iOS documents in `docs/` (`alarmkit-findings.md`, `product-brief.md` — never `docs/design/`) and `PhotoAlarm.xcodeproj`, rewrites the project-owned sections of `AGENTS.md`, and marks the iOS spec, the iOS epic plan and ADR-0025 as superseded/deprecated (kept as history). The product glossary and invariants were reset during this session | A pivot, not a second product; git keeps the iOS history, and the scaffold is already current with upstream |
| 2 | Technical base | Same as Caffeinassy: menu-bar agent (`LSUIElement`), AppKit `NSStatusItem` plus a SwiftUI panel, XcodeGen, App Sandbox (see #31), Swift Testing, deployment target macOS 26.0 | Known, proven patterns from the sibling app; no new architecture to learn |
| 3 | Keeping the Mac awake for an Alarm | An IOKit power assertion that prevents idle System sleep (scope narrowed by #17). At a Ring the app wakes the display and keeps it on while the Ring sounds. Documented requirement: lid open, Mac on power | A sandboxed app cannot wake a sleeping Mac, and a MacBook sleeps on lid close regardless of assertions |
| 4 | Alarm model | Several Alarms, each a time plus weekdays, each Armed or Disarmed on its own | Matches real use: different times on different days |
| 5 | Typing challenge text | 6 random common Spanish words, lowercase, no accents or ñ, from a word list bundled in the app, drawn fresh for every Ring. Paste and drag-and-drop are blocked. Typed input is lowercased before comparing, so Caps Lock does not matter; words are separated by single spaces — a double space is marked as an error — and one trailing space is tolerated. A mistake does not reset progress *(amended to match the prototype)* | Hard enough to need a working brain, easy enough on a Spanish keyboard at 7 a.m. |
| 6 | Escape while a Ring sounds | Full-screen window above every other window; the status menu offers no Quit during a Ring. Force Quit stays available as the emergency exit | Blocks the casual escape without trapping the user if the app itself breaks; kiosk lockdown rejected for that risk |
| 7 | Disarming before a Ring | Free: switching an Alarm off or editing it before it rings never asks for the Typing challenge | Only a Ring needs the challenge; holidays and early wake-ups should not |
| 8 | Ring volume | At Ring start the app unmutes and ramps the system output volume to maximum over about 30 s | A muted or low Mac must not mean a silent alarm; feasibility under the Sandbox is a spike (#31) |
| 9 | Bedtime behavior | Plays rain until switched off or until a Ring replaces it | Continuous sound also keeps Bluetooth speakers from auto-powering off overnight |
| 10 | Rain source | Generated in code with AVAudioEngine (filtered noise plus random drops); no audio assets | No files, no licences, no loop seam; can be swapped for a recording later |
| 11 | Canonical name of the rain mode | **Bedtime** (the Spanish UI may label it "Modo dormir") | "Sleep mode" collides with macOS System sleep, the very thing that stops an Alarm |
| 12 | App identity | Display name "Wake Up Human"; folders and targets `WakeUpHuman/`, `WakeUpHumanTests/`; bundle ID `com.ovct.wakeuphuman` | Follows the repo name and Caffeinassy's `com.ovct.*` convention |
| 13 | Snooze | None — the Typing challenge is the only way to Dismiss a Ring | A wake-up app with a snooze button is a snooze app |
| 14 | Unattended Ring | A Ring nobody Dismisses stops by itself after 60 minutes, and the panel then shows an unattended-Ring notice | Ringing all day while the user is away helps nobody |
| 15 | Overlapping and missed Alarms | One Ring at a time: an Occurrence due during a Ring joins it, and one Dismiss ends both. An Occurrence missed while the Mac slept or the app was closed never rings late | Two challenges back to back add nothing; a late Ring surprises more than it helps |
| 16 | Volume after Dismiss | Restore the system volume and mute state from before the Ring | The Ring borrowed the volume; it gives it back |
| 17 | When the keep-awake assertion is held | Only while Bedtime is on; Bedtime is the only thing keeping the Mac awake while it waits for an Alarm (ADR-0027) | Tied to the nightly ritual; holding it whenever an Alarm is Armed would block idle sleep all weekend |
| 18 | Launch at login | On by default, through `SMAppService`; the panel shows the live registration status and can switch it off | An alarm app that is not running is a broken alarm |
| 19 | Alarm sound | One loud, pulsing tone generated in code with AVAudioEngine, shared by every Alarm | Same no-asset approach as the rain |
| 20 | Rain volume | Its own slider in the panel, independent of the system volume | Set the rain level once without touching the system volume the Ring will borrow |
| 21 | Where Alarms and Bedtime are managed | Everything in the menu-bar panel: the Bedtime toggle and rain slider on top, the Alarm list with inline add and edit (time and weekdays) below. The Ring window is the only other window | A settings window in an `LSUIElement` app brings focus and Dock bugs, as Caffeinassy found |
| 22 | An Alarm with no weekday | Rings once, at the next Occurrence of its time, then Disarms itself | Covers one-off mornings (a flight) the way the iPhone Clock does |
| 23 | Storage | UserDefaults, the Alarm list as Codable JSON | A short list and a few settings need no database |
| 24 | ADR for XcodeGen | Raised: ADR-0026 | Passes all three ADR tests |
| 25 | Panel notices | Missed Occurrence; Bedtime off with an Armed Alarm due within 12 hours; on battery while Bedtime is on; "next alarm" (or "no upcoming alarm") under the Bedtime toggle — plus the unattended-Ring notice from #14. The missed and unattended notices stay until acknowledged ("Entendido"); the Bedtime-off notice offers "Activar modo dormir"; the battery notice clears itself once the Mac is plugged in or Bedtime ends *(clearing rules from the prototype)* | Since only Bedtime keeps the Mac awake, the panel must make a likely silent morning visible |
| 26 | Bedtime with no upcoming Alarm | Allowed; it runs until switched off, and the panel says there is no upcoming alarm | Rain alone is a legitimate use |
| 27 | Product invariants | 3: no network calls (kept, reworded). 4: a Ring ends only when Dismissed or at its unattended cap. 5: an Occurrence never rings late. 6: only Bedtime keeps the Mac awake while it waits for an Alarm (a Ring keeps the display on) | Promoted by the user so that a breach is a hard violation at the review gate |
| 28 | Distribution | Same as Caffeinassy: a `v*` tag builds a universal (arm64 + x86_64), ad-hoc-signed, un-notarized DMG and publishes it on GitHub Releases with Gatekeeper install notes; a manual dispatch uploads the DMG as an artifact only | Proven pipeline; no Apple Developer membership for a personal app |
| 29 | ADR for the Bedtime-only assertion | Raised: ADR-0027 | Surprising, a real trade-off, and exactly what a later contributor would "fix" |
| 30 | CI trigger | Pull requests only (for example the epic → main PR), running `xcodegen generate`, build and test *(superseded by `.agents/specs/2026-11-02-open-source-readme.md`, decision 2: pull requests and pushes to `main`)* | The repo is private: macOS runner minutes count ten-fold, and every child integration already builds and tests in the local review gate |
| 31 | If the App Sandbox blocks setting the system volume | Drop the Sandbox and keep the forced volume | A personal app with no App Store plans; an alarm that can be silent is worse than losing the Sandbox |
| 32 | Menu-bar icon | Six states, as in `docs/design/status-icon.html`: dimmed alarm clock (no Alarm Armed), full alarm clock (an Alarm Armed), moon (Bedtime on), a yellow dot added for any pending notice, moon with the dot (Bedtime on battery), filled orange while a Ring sounds. The glyph stays a monochrome template image; only the dot and the ringing tint are coloured. The Finder/DMG app icon is generated by a script, as in Caffeinassy *(amended to match the prototype)* | State and pending notices visible at a glance without opening the panel |
| 33 | Typing feedback | Live, as in `docs/design/ring-window.html`: each of the six words in its own box, typed characters coloured as done, wrong (red) or pending with a cursor, a "N de 6 palabras" progress bar, and the Ring is Dismissed the moment the text matches — no Enter *(detailed from the prototype)* | Less friction at 7 a.m.; the challenge is the typing, not the confirmation |
| 34 | Design reference | The prototype's screens live in `docs/design/` (panel, status icon, Ring window), extracted without fonts. Where this spec is silent on layout, copy or colour, they govern; where the two disagree, this spec governs | Implementing agents need the visual design in the repo, not in a Downloads folder |
| 35 | Panel details from the prototype | Inline edit offers "Eliminar" (delete, free like Disarm); saving an edit re-Arms the Alarm; a new Alarm starts at 07:00 with no weekday; the list is sorted by time; "next alarm" also shows a countdown; the Bedtime block states its lid-open, plugged-in requirement; the rain slider dims while Bedtime is off; an empty list says how to add one | The prototype settled these and none contradicts a decision above |
| 36 | Panel footer | A launch-at-login row with a switch showing the live `SMAppService` status (#18), plus "Salir ⌘Q", which is unavailable while a Ring sounds (#6) | The prototype had only Quit; the spec's login-item control needed a home |
| 37 | After Dismiss | The Ring window shows an "Alarma apagada" confirmation — volume and mute restored, how long it rang — and closes after 5 s or on any key or click | Confirms the Ring is over and the volume is back before the window disappears |
| 38 | Ring window extent | Covers the main display; on any other display the menu bar, with the ringing icon, stays visible | Stated by the prototype's icon sheet; on the MacBook alone it is the whole screen |

## Explicitly Out of Scope

- **Snooze**, in any form (#13).
- **Kiosk lockdown** during a Ring — blocking ⌘-Tab, Force Quit, the Dock or the menu bar (#6).
- **Waking a sleeping Mac**: `pmset schedule wake`, `IOPMSchedulePowerEvent`, or any privileged
  helper (ADR-0027).
- **Holding the keep-awake assertion whenever an Alarm is Armed**, or in a window before the next
  Occurrence (ADR-0027, invariant 6).
- **Ringing a missed Occurrence late** (invariant 5).
- **Audio files**: recorded rain, bundled or system alarm sounds; and a different sound per Alarm
  (#10, #19).
- **A settings window** or SwiftUI `Settings` scene (#21).
- **System notifications** (`UNUserNotificationCenter`) — the panel notices and the Ring window are
  the whole UI.
- **Developer ID signing, notarization, Mac App Store submission** (#28).
- **CI on every push** or on `epic/**` pushes (#30).
- **The iOS app**, AlarmKit, the camera mission and everything else from the retired Photo Alarm.
- **Network, accounts, sync, analytics** (invariant 3).

## Glossary Changes

All in this session:

- `.agents/ubiquitous-language.md` — retired the Photo Alarm vocabulary (Alarm as `WakeAlarm`,
  System alarm, Ring, Follow-up, Wake-up session, Mission, Target object, Reference, Photo check,
  Fallback) and the flagged ambiguity "alarm". Added the Alarms area (Alarm, Armed, Occurrence,
  Ring, Dismiss, Typing challenge), the Bedtime area (Bedtime), and the flagged ambiguities "sleep"
  (System sleep vs Bedtime) and "turn off" (Disarm vs Dismiss). The Canonical code header reads
  "none yet" until the macOS app's domain folders exist.
- `.agents/ubiquitous-language-invariants.md` — retired invariants 1 and 2 (numbers never reused);
  reworded 3 (no network calls); added 4 (a Ring ends only when Dismissed or at its unattended
  cap), 5 (an Occurrence never rings late) and 6 (only Bedtime keeps the Mac awake while it waits
  for an Alarm; a Ring keeps the display on).
- `.agents/ubiquitous-language-changelog.md` — one row per change above;
  `.agents/ubiquitous-language-index.md` regenerated.

## ADRs Raised

- `.agents/adr/0026-xcodegen-generates-the-project.md` — XcodeGen generates the Xcode project; no
  `.xcodeproj` in version control
- `.agents/adr/0027-only-bedtime-keeps-the-mac-awake.md` — Only Bedtime keeps the Mac awake; the
  app never wakes a sleeping Mac

## Residual Unknowns

- **System volume under the App Sandbox.** Whether a sandboxed app may unmute and set the default
  output device's volume through CoreAudio is unverified. It needs a spike early in the work; #31
  already settles the fallback (drop the Sandbox).
- **Lock screen.** If the Mac locks when the display turns off, the Ring window cannot draw above
  the lock screen. The Ring still sounds, the user unlocks (Touch ID), then types. This is accepted
  behavior; it needs confirming on the device.
- **Overnight restarts.** With FileVault on, a restart (for example a macOS update) stops at the
  password screen and no app runs until login, so that morning's Alarm cannot ring. Launch at
  login (#18) covers only restarts followed by a login.
- **CI runner image.** The deployment target (macOS 26) needs Xcode 26 or later on the runner;
  Caffeinassy's workflows pin `macos-15` with Xcode 16. The workflow must select an image that
  carries a new enough Xcode.
- **Generated sound quality.** Whether the procedural rain and alarm tone sound acceptable is
  judged by ear on the device, not by tests.
- **Bluetooth fallback.** Without Bedtime a Bluetooth speaker may auto-power-off; macOS then routes
  the Ring to the MacBook's built-in speakers. Accepted, not engineered around.
- **Scaffold-owned files naming PhotoAlarm.** `.agents/rules/domain-glossary.md` (canonical domain
  paths) and `.agents/rules/testing.md` (placement and harness) carry iOS project specifics. The
  first slice must rewrite them for `WakeUpHuman/`; a later scaffold sync will flag them as
  divergent, as it would have for the iOS values.
