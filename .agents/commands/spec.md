# Command: spec

One-shot pipeline: decompose a large spec into an epic + child issues, pause for
human review, then auto-advance every wave into the epic integration branch. This
command **chains** `/spec-breakdown` and, for Phase 3, either `/execute-epic` or
`/supervise-epic`; it does not duplicate their logic.

`$ARGUMENTS` — spec text or path to a spec file, optionally followed by the
`--supervised` flag (passed through to `/spec-breakdown` after the flag is
stripped — see Phase 0).

## Context injected by the wrapper

- **Harness mode** — the injected `sh .agents/scripts/harness-mode.sh` output: a `Mode:`
  line (`github`, `local` or `refused`), then `Remote: <url>` / `Remote: (none)`, or
  `Reason: <message>` when refused.
- **Current branch** — from `git rev-parse --abbrev-ref HEAD`

## Instructions

### Phase 0 — Parse arguments

`$ARGUMENTS` may contain the flag `--supervised`, anywhere in the string, surrounded
by whitespace. If present, strip it and set `EXECUTION = supervised`; otherwise
`EXECUTION = auto` (the default — unattended execution behind the agentic review
alone, same as calling `/execute-epic` directly). The remainder, trimmed, is the spec
input carried into Phase 1 — untouched otherwise, so a file path or free-form spec
text still passes through exactly as typed.

Read the injected `Mode:` line: `refused` → stop and relay the `Reason:` line; otherwise
state the active mode before Phase 1 writes anything. The same mode governs both phases —
an epic lives entirely in the backend that created it.

### Phase 1 — Breakdown

Follow `.agents/commands/spec-breakdown.md` exactly, passing the spec input from
Phase 0 as the spec argument. Complete every step it defines for the active mode, through
its report.

### Phase 2 — Review pause

Present the created epic (GitHub mode: its URL and number; local mode: its `local-<n>` ID
and plan path), every child (its URL, or its `local-<n>` ID and plan path) and branch,
the computed waves,
and which execution path Phase 3 will use (`EXECUTION` from Phase 0). Then **stop and
ask the user** to confirm the decomposition before proceeding.

The user may:
- **Approve** → proceed to Phase 3.
- **Request changes** → edit the epic/child issues (local mode: their plan files) or
  re-run `/spec-breakdown` with a
  revised spec; do not proceed.
- **Cancel** → stop.

Do not auto-proceed. A pause here is mandatory.

### Phase 3 — Execute

Once the user approves, follow `.agents/commands/execute-epic.md`, passing the epic just
created as its epic argument — `#<epic>` in GitHub mode, `local-<n>` in local mode
(`parallel-orchestration.md` › Selecting the Epic), so it never resolves from the branch
or asks — unless Phase 0 set `EXECUTION = supervised`, in which case follow
`.agents/commands/supervise-epic.md` instead, with the same epic argument. Either way,
the `skip confirm` flag is implicit (the review pause in Phase 2 served that purpose); do
not ask for another confirmation before the wave loop starts. On the supervised path this does **not**
skip the per-child review gate (`skip confirm` only ever skips the plan-display
confirmation, never the human decision per child) — you will still be asked to
approve or reject each child as it comes up for review.

Execute through the final step of whichever command Phase 3 selected, which
auto-advances all runnable waves in one run — every child passes push → agentic
review → optional rework → integrate before it lands on the epic branch, and the
command hands the epic off at completion — one `epic → main` PR in GitHub mode, a
printed push in local mode.

## Rules

- Phases 1 and 3 delegate entirely to their canonical specs; do not duplicate logic.
- The pause in Phase 2 is mandatory — never auto-proceed to execution.
- `EXECUTION` defaults to `auto` (`/execute-epic`); only an explicit `--supervised` at
  the call site routes Phase 3 to `/supervise-epic`. `/spec` never infers this from
  context — the opt-in must be visible in what the user typed.
- If Phase 1 fails (fewer than 3 slices, duplicate epic, etc.), stop and report;
  do not attempt Phase 3.
