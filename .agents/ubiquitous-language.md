# Ubiquitous Language

> Single source of truth for current domain and technical terminology.
> Read this before changing canonical types, states, processes, or data contracts.
>
> **Last updated:** 2026-11-01
> **Canonical code:** `WakeUpHuman/Alarms/`, `WakeUpHuman/Ring/`, `WakeUpHuman/Bedtime/`, `WakeUpHuman/Notices/`, `WakeUpHuman/Power/`
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

What rings, when, and how a ringing alarm is silenced.

| Term | Canonical type | Aliases to avoid | Notes |
|------|----------------|------------------|-------|
| Alarm | user-configured alarm | *timer*, *reminder* | A wake-up time plus the weekdays it repeats on. With no weekday it rings once, at the next Occurrence of its time, then Disarms itself. The user may configure several, each Armed or Disarmed on its own. |
| Armed | Alarm state (opposite: Disarmed) | *enabled*, *active*, *on* | An Armed Alarm rings at its next Occurrence, provided the Mac is awake then. Disarming is switching an Alarm off before it rings, from the panel, and never asks for the Typing challenge. |
| Occurrence | one due date-and-time of an Armed Alarm | *instance*, *trigger* | One moment an Armed Alarm is due. An Occurrence that passes while the Mac is in System sleep or the app is not running is missed: it never rings late. |
| Ring | one sounding of an Alarm | *alert*, *fire* | One time an Alarm sounds, with the Typing challenge covering the main display above every other window. It ends only when Dismissed or when its unattended cap runs out; there is no snooze. An Occurrence due during a Ring joins it instead of starting a second one. |
| Dismiss | ending a Ring | *stop*, *turn off*, *deactivate* | Ending the current Ring by completing its Typing challenge. Dismiss acts on a Ring already sounding; Disarm acts on an Alarm before it rings. |
| Typing challenge | shown text + typed input | *mission*, *puzzle*, *captcha* | The text shown during a Ring that must be retyped, letter for letter in any case, to Dismiss it. Drawn fresh for every Ring; pasting or dropping text never fills it. |

### Bedtime

What plays while the user falls asleep.

| Term | Canonical type | Aliases to avoid | Notes |
|------|----------------|------------------|-------|
| Bedtime | rain playback + keep-awake mode | *sleep mode*, *rain mode*, *sleep* (unqualified) | The mode that plays generated rain and keeps the Mac out of System sleep until it is switched off or a Ring replaces it. The only thing that keeps the Mac awake, so an Alarm Armed without Bedtime may not ring. Never System sleep itself. |

### Panel

What the menu-bar panel tells the user.

| Term | Canonical type | Aliases to avoid | Notes |
|------|----------------|------------------|-------|
| Notice | panel notice | *notification*, *alert*, *warning* | A message at the top of the panel about a missed Occurrence, an unattended Ring, Bedtime off with an Armed Alarm due within 12 hours, or Bedtime on battery; never a system notification. |

---

## Flagged ambiguities

- **"sleep"** — macOS uses it for the system's idle or lid-closed rest, which stops every Alarm
  from ringing. Say **System sleep** for that, and **Bedtime** for the rain mode.
- **"turn off"** — say **Disarm** for an Alarm that is not ringing yet, and **Dismiss** for a
  Ring that is sounding now.
