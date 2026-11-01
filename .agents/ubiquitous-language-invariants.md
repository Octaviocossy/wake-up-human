# Ubiquitous Language — Invariants

> Every invariant **this project's product** commits to. A breach of one is a **hard violation**
> at the review gate. **Owned by the project** — the scaffold ships this file empty and never
> rewrites it. The harness's own invariants live in
> `.agents/ubiquitous-language-invariants-scaffold.md` (scaffold-owned, identifiers `S1`, `S2`, …);
> do not copy them here. Number product invariants plainly — `**1. …**`, `**2. …**` — and append,
> never renumber, so a citation stays stable and never collides with an `S` identifier.
>
> **Last updated:** 2026-11-01
> **Budget:** notes 600 · warn 24576 · fail 32768 (bytes)

---

## Invariants and relationships

Numbers 1 and 2 are retired and never reused.

- **3. The app makes no network calls.** No backend, accounts, analytics or sync: Alarms and
  settings never leave the Mac.
- **4. A Ring ends only when Dismissed or when its unattended cap runs out.** There is no snooze,
  and the app offers no Quit while a Ring sounds. Force Quit stays available, deliberately, as the
  emergency exit when the app itself is broken.
- **5. An Occurrence never rings late.** One that passes while the Mac is in System sleep or the
  app is not running is reported as missed, never rung afterwards.
- **6. Only Bedtime keeps the Mac awake while it waits for an Alarm.** A Ring keeps the display on
  while it sounds. Nothing else holds a power assertion that prevents sleep, and the app never
  schedules a wake (ADR-0027).
