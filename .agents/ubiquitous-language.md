# Ubiquitous Language

> Single source of truth for current domain and technical terminology.
> Read this before changing canonical types, states, processes, or data contracts.
>
> **Last updated:** 2026-10-31
> **Canonical code:** `PhotoAlarm/Alarm/`, `PhotoAlarm/Mission/`, `PhotoAlarm/Vision/`, `PhotoAlarm/Persistence/`
> **Budget:** notes 600 · warn 81920 · fail 102400 (bytes)

This file holds **this project's own domain vocabulary** and is **owned by the project** — the
scaffold ships it as an empty template. It is one of six (ADR-0016, ADR-0017, ADR-0021):

| File | Holds | Owner |
|------|-------|-------|
| `.agents/ubiquitous-language.md` | this project's domain vocabulary | the project |
| `.agents/ubiquitous-language-scaffold.md` | the harness's own vocabulary | the scaffold |
| `.agents/ubiquitous-language-invariants.md` | this project's product invariants | the project |
| `.agents/ubiquitous-language-invariants-scaffold.md` | the harness's own invariants (`S1`, `S2`, …) | the scaffold |
| `.agents/ubiquitous-language-index.md` | generated term → area pointer table | generated |
| `.agents/ubiquitous-language-changelog.md` | dated history of the family | both |

The index and both invariants files are `@`-imported by `CLAUDE.md`; the vocabulary bodies are
read on demand.

---

## How to maintain this document

1. Describe current behavior, not release history or superseded implementations.
2. Add only terminology that clarifies naming, ownership, a data contract, or an invariant.
3. Keep definitions concise and use aliases to prevent recurring ambiguity.
4. Update the date and Changelog when canonical vocabulary or an invariant changes.

---

## Glossary

### Alarms

What rings, and how rings group into one morning's wake-up.

| Term | Canonical type | Aliases to avoid | Notes |
|------|----------------|------------------|-------|
| Alarm | `WakeAlarm` (SwiftData model) | *base alarm*, *recurring alarm* | A wake-up time plus at least one weekday, configured by the user. Its AlarmKit registration is a System alarm, never an Alarm; the type is not named `Alarm` so it cannot shadow `AlarmKit.Alarm`. |
| System alarm | `AlarmKit.Alarm` | *alarm* (unqualified) | Any alarm registered with AlarmKit: an Alarm's weekly registration or a Follow-up. Cancelling a System alarm never edits an Alarm. |
| Ring | one alerting presentation | *alert*, *fire* | One time a System alarm sounds, drawn by the system with the Stop and "Take photo" buttons. A Ring is not a Wake-up session: only an Alarm occurrence's first Ring opens one. |
| Follow-up | one-off System alarm | *snooze*, *re-alarm* | A Ring the re-alarm loop schedules shortly after a Ring of an open Wake-up session ends through Stop or "Take photo", capped per session. Only a completed Mission cancels it. It belongs to the session of the Ring it follows and never opens a new one. There is no snooze. |
| Wake-up session | `WakeUpSession` (persisted by `MissionStateStore`) | *session* (unqualified) | One occurrence of an Alarm, from its first Ring until its Mission is completed, or until its Follow-up window closes and it is abandoned. One per occurrence, never one per Ring; a dead loop does not end it early. |

### Wake-up mission

What must be done to end a Wake-up session.

| Term | Canonical type | Aliases to avoid | Notes |
|------|----------------|------------------|-------|
| Mission | completion of a Wake-up session | *challenge* | What completes a Wake-up session: a Photo check returning Match, or a completed Fallback. Nothing else completes it; Stop only ends the current Ring. |
| Target object | registered physical object | *item*, *object* (unqualified) | The one physical object whose photo completes the Mission. Exactly one, global to every Alarm; re-registering it replaces all its References. |
| Reference | archived Vision feature print (`Data`) | *sample*, *template* | The stored feature print of one setup photo of the Target object, taken from the live camera. The Target object has 3 to 5. |
| Photo check | live photo vs. every Reference | *scan*, *verification* | Comparing one live camera photo against every Reference: **Match** when the smallest distance is under the calibrated threshold, otherwise **No match**. A No match is a failed attempt toward the Fallback. |
| Fallback | emergency challenge | *emergency mode*, *backup* | The challenge that completes the Mission without a Match, for a lost or moved Target object. It unlocks only after repeated failed Photo checks in the same Wake-up session. |

---

## Flagged ambiguities

- **"alarm"** — AlarmKit calls every registration an `Alarm`; this domain does not. Say **Alarm**
  for the user's configured time and weekdays, **System alarm** for an AlarmKit registration, and
  **Ring** for one sounding.
