# Spec: Photo Alarm MVP

> Status: **settled**
> Created: 2026-10-31
> Grilled: 2026-10-31 — 4 rounds, 23 decisions
> Suggested next: /spec-breakdown

## Goal

Build Photo Alarm: a personal iOS 26 alarm clock (SwiftUI, AlarmKit, Vision) for one user on one
iPhone. A Wake-up session ends for good only when the user photographs the registered Target
object, or completes the Fallback. The baseline is `docs/product-brief.md`. Everything in it that
this spec does not override still stands, including its milestones M0–M5, technical approach,
on-device checklist and risk table.

## Settled Decisions

| # | Decision | Chosen | Rationale |
|---|----------|--------|-----------|
| 1 | Signing: paid Apple Developer Program or free Personal Team? | Free Personal Team, permanently; builds expire every 7 days | User's choice; the expiry is mitigated by decision 20 |
| 2 | What keeps the re-alarm loop alive? | Only the alarm-button intents arm a Follow-up. A dismissal that runs no app intent ends the loop on purpose | Leaves a deliberate escape for a morning when the user is already up or away from the phone (ADR-0025) |
| 3 | Follow-up interval and cap | 60 s interval, at most 20 Follow-up Rings per Wake-up session | Twenty minutes of rings every minute is enough pressure, and a phone left at home stops eventually |
| 4 | Snooze? | No snooze. A Follow-up is the only reprieve, and the secondary alarm button is "Take photo" only | A long snooze would undo the app's purpose |
| 5 | Fallback unlock and difficulty | Unlocks after 5 failed Photo checks in the same session. Then 15 random arithmetic problems (e.g. `47×8+23`); a wrong answer resets the count to 0; progress is persisted | It must cost more than walking to the Target object, or photographing the ceiling from bed becomes the shortcut |
| 6 | What the app allows while a Wake-up session is open | Only the mission screen, whatever the entry point; Object setup and alarm management are locked | Otherwise registering the pillow or disabling the Alarm skips the Mission |
| 7 | Target object lifecycle | One global Target object. Re-registering replaces all its References. No Alarm can be enabled until the object is registered and its test Photo check passes | Without the gate, a fresh install's first Alarm can only be ended by the Fallback |
| 8 | Matching configuration | Fixed threshold constant in code, calibrated in M2 and re-calibrated from the debug screen if the object changes. 3–5 References, minimum 3. No label-text (OCR) check unless M2 shows a similar bottle passing | Simplest matcher that the M2 data can justify |
| 9 | Alarm rules | Each Alarm needs ≥1 weekday, so no one-off Alarms. Multiple Alarms are allowed. Each Alarm occurrence opens its own Wake-up session, and a Match completes every session open at that moment | Overlapping Alarms (7:00 and 7:10) get a defined outcome: a session already completed does not cover a later occurrence |
| 10 | Which brief rules become product invariants | Camera only (never the photo library); Mission state persisted; no network calls (invariants 1–3). "No third-party dependencies" stays a brief guideline, not an invariant | A breach of these defeats the product, so the review gate treats one as a hard violation |
| 11 | Fate of the M1/M2 spike screens | Kept in `PhotoAlarm/Debug/`, compiled in Debug builds only | Re-running the on-device checklist after each iOS update and re-calibrating after an object change both need them |
| 12 | Domain vocabulary | Alarm (`WakeAlarm`), System alarm, Ring, Follow-up, Wake-up session, Mission, Target object, Reference, Photo check (Match / No match), Fallback | The brief used "alarm" for three different things and "mission"/"session" interchangeably |
| 13 | Who creates the Xcode project | The agent writes it; the user does not run the Xcode wizard | No manual setup step |
| 14 | Toolchain recorded in `AGENTS.md` | Swift Testing in `PhotoAlarmTests/` mirroring `PhotoAlarm/`; `xcodebuild -scheme PhotoAlarm -destination 'platform=iOS Simulator,name=iPhone 17' build` / `test`; `swift format lint --strict`. M0 fills `AGENTS.md` › Commands, Testing and Code Structure, and the canonical domain paths in `.agents/rules/domain-glossary.md` | Child agents read `Build:` and `Test:`; the formatter ships with the toolchain, so nothing is added |
| 15 | Does "Take photo" also arm a Follow-up? | Yes. Opening the mission from the Ring schedules a Follow-up 60 s out, and only a completed Mission cancels it | Otherwise "Take photo" then leaving the app is an escape button, contradicting the brief's "the loop keeps running" |
| 16 | When does a session whose loop died end? | It is abandoned when its Follow-up window closes (first Ring + 20 × 60 s), never earlier and never later | A side-button dismissal while travelling without the object must not lock the app in mission mode all day |
| 17 | Widget Extension and App Group | Neither. Mission state lives in the app's own container | AlarmKit requires a widget extension only for a countdown presentation, which no snooze means no Alarm uses. The intents run in the app process. App Groups on a free team are unconfirmed |
| 18 | How the agent generates the Xcode project | A hand-written minimal `project.pbxproj` in the Xcode 16+ format with synchronized folders; no XcodeGen or Tuist | Files added under `PhotoAlarm/` or `PhotoAlarmTests/` never touch the project file, which keeps parallel children free of `pbxproj` conflicts |
| 19 | Project location and signing identifiers | Repo root: `PhotoAlarm.xcodeproj`, `PhotoAlarm/`, `PhotoAlarmTests/`. Bundle id `com.ovct.photoalarm`. `DEVELOPMENT_TEAM` is left empty by the agent; the user picks the Personal Team once in Xcode and it is committed | The team ID is not a secret, and the agent cannot know it. The brief's "initialize a git repo" step becomes "append Xcode entries to the existing `.gitignore`" |
| 20 | Free-signing expiry mitigation | The app reads the expiry date from its embedded provisioning profile and shows a banner with the days left, red at ≤2 days; plus the user's own weekly calendar reminder | An expired build cannot launch: the Ring sounds once, Stop arms nothing, and the Mission is impossible |
| 21 | Follow-ups while the mission screen is open | While the mission screen is in the foreground, the app keeps pushing the pending Follow-up to now + 60 s. Locking the screen or leaving the app lets it ring within 60 s. Postponing does not consume the cap | Rings every minute would interrupt the ~5-minute Fallback; postponing keeps a dead-man's switch on the mission |
| 22 | Record the loop design as an ADR? | Yes: ADR-0025, with the deliberate escape as its rationale | A reader of the AlarmKit `stopIntent` reports would otherwise "fix" it by pre-scheduling Follow-ups |
| 23 | Execution path | GitHub mode: `/spec-breakdown` into an epic whose children follow M0–M5, executed with `/supervise-epic` | The human gate per child is where the user verifies on the iPhone. `/supervise-epic` is resumable, so a gate may wait for morning-light calibration (M2) or the week of daily use (M5). The user chose this over one issue per milestone; spike results reach later children through `/update-issue` |

## Explicitly Out of Scope

- Ending the loop only by Match or Fallback, i.e. making every dismissal re-arm. The user rejected
  it in favor of a deliberate escape (decision 2).
- Pre-scheduling the Follow-up chain as System alarms, and AlarmKit's native Repeat
  (`secondaryButtonBehavior: .countdown`). Both rejected in ADR-0025.
- Snooze of any length (decision 4).
- One-off Alarms with no weekday (decision 9).
- More than one Target object, or one object per Alarm, including data-model hooks for it
  (decision 7).
- A label-text (OCR) check, unless M2 shows a similar bottle passing (decision 8).
- A user-adjustable match threshold or any settings screen for it (decision 8).
- A Widget Extension, Live Activity customization, and the App Groups capability (decision 17).
- The paid Apple Developer Program and TestFlight (decision 1).
- XcodeGen, Tuist, or any other project generator (decision 18).
- Any network call, backend, account, analytics or sync (invariant 3).
- Everything the brief already lists out of scope: custom alarm sounds, the photo library, iCloud
  sync, widgets beyond what AlarmKit requires, App Store distribution, onboarding, localization,
  Android.

## Glossary Changes

- `.agents/ubiquitous-language.md` › Alarms (new area): **Alarm** (`WakeAlarm`), **System alarm**,
  **Ring**, **Follow-up**, **Wake-up session**. Follow-up and Wake-up session were sharpened in
  round 2: armed by Stop or "Take photo", and abandoned when the Follow-up window closes.
- `.agents/ubiquitous-language.md` › Wake-up mission (new area): **Mission**, **Target object**,
  **Reference**, **Photo check** (Match / No match), **Fallback**.
- `.agents/ubiquitous-language.md` › Flagged ambiguities: **"alarm"**. AlarmKit calls every
  registration an `Alarm`; this domain distinguishes Alarm, System alarm and Ring.
- `.agents/ubiquitous-language-invariants.md`: product invariants **1** (never reads the photo
  library), **2** (Mission state persisted, never held only in memory) and **3** (no network
  calls).
- `.agents/ubiquitous-language-changelog.md`: three rows dated 2026-10-31.
- `.agents/ubiquitous-language-index.md`: regenerated.

## ADRs Raised

- `.agents/adr/0025-re-alarm-loop-is-armed-only-by-alarm-button-intents.md` — The re-alarm loop
  is armed only by alarm-button intents

## Residual Unknowns

These are facts, not decisions. Each is measured in the milestone named, and none blocks
decomposition.

- **Which dismissals run `stopIntent` on the user's iOS version** (M1). Apple's FAQ says a swipe and
  a power-button press do. A developer report on iOS 26.2.1 says a banner swipe and an
  unlocked-screen interaction do not. If the side button runs it, the side button re-arms a
  Follow-up and is not an escape (ADR-0025).
- **How long an unanswered Ring sounds before it stops by itself** (M1). Undocumented. An ignored
  Ring runs no intent, so it ends the loop.
- **Whether postponing a Follow-up from the foreground is reliable** (M1/M3). Decision 21 cancels
  and re-schedules a System alarm repeatedly while the mission screen is open.
- **The match threshold value** (M2). Calibrated from logged distances: the Target object versus
  at least five other objects, in two or three lighting conditions.
- **A new risk for the brief's checklist and risk table.** AlarmKit alarms of an app that is hidden,
  or that requires Face ID or a passcode to open, fail silently (AlarmKit FAQ). Never hide or lock
  Photo Alarm.
