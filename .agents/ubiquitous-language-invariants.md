# Ubiquitous Language — Invariants

> Every invariant **this project's product** commits to. A breach of one is a **hard violation**
> at the review gate. **Owned by the project** — the scaffold ships this file empty and never
> rewrites it. The harness's own invariants live in
> `.agents/ubiquitous-language-invariants-scaffold.md` (scaffold-owned, identifiers `S1`, `S2`, …);
> do not copy them here. Number product invariants plainly — `**1. …**`, `**2. …**` — and append,
> never renumber, so a citation stays stable and never collides with an `S` identifier.
>
> **Last updated:** 2026-10-31
> **Budget:** notes 600 · warn 24576 · fail 32768 (bytes)

---

## Invariants and relationships

- **1. The app never reads the photo library.** Every Reference and every Photo check comes from a
  live camera capture. A stored photo of the Target object would complete the Mission without
  getting out of bed.
- **2. Mission state is persisted, never held only in memory.** App code runs only in short bursts —
  scheduling, an alarm-button intent, an opened mission — so a Wake-up session's state must survive
  the process that wrote it.
- **3. The app makes no network calls.** No backend, accounts, analytics or sync: Alarms,
  References and Photo checks never leave the device.
