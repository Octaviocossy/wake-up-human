# Ubiquitous Language

> Single source of truth for current domain and technical terminology.
> Read this before changing canonical types, states, processes, or data contracts.
>
> **Last updated:** 2026-09-13
> **Canonical code:** _not yet documented — list this project's domain source directories here_
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

_No domain entities documented yet. Add a table per bounded area as the project grows, e.g.:_

| Term | Canonical type | Aliases to avoid | Notes |
|------|----------------|------------------|-------|
| _Entity_ | `TypeName` (`path/to/file`) | _alias to avoid_ | _one-line definition_ |

---

## Flagged ambiguities

_None documented yet._
