# Local mode is a `USE_GITHUB` knob in `.agents/harness.config`

The epic pipeline and the issue commands reach GitHub through the MCP server, and the runner pushes
every child branch to `origin`. A developer who cannot or will not use the shared tracker — a
contributor in a repository whose issues they do not own — had no way to run them.
`USE_GITHUB=false` in `.agents/harness.config` now switches the harness to **local mode**: issues
and epics are plan files under `.agents/plans/`, identified `local-<n>`; no GitHub API is called;
and no remote is read or written. The epic branch stays local until the user pushes it. When the
knob is absent or `true`, the harness behaves as it always has.

ADR-0006 rejected a flag in this same per-machine file, because the flag decided a session's
shape — whether a human is required — invisibly, machine by machine. `USE_GITHUB` decides neither.
It chooses where the tracker lives and whether anything leaves the machine. That is a property of
the developer's access, like `AGENT_EXEC_CMD`, so it belongs with the other per-machine knobs. The
invisibility ADR-0006 objected to is answered by making the mode legible: every command states the
active mode in its confirmation, before it writes anything. The file was renamed from
`.agents/parallel.config` because it now configures the issue commands too, not only the parallel
runner.

## Considered Options

- **A call-site flag (`--local`) on every command.** Rejected: it has to be repeated on every
  command, and forgetting it on `/execute-epic` after a local `/spec-breakdown` loses the epic.
- **Inferring the mode from the epic itself.** Rejected: it adds machinery, and it cannot cover
  `/create-issue`, which runs before any epic exists.
- **Keeping the name `parallel.config`.** Rejected: the file's own header scoped it to the runner.

## Consequences

The rename is enforced, not bridged. When `.agents/parallel.config` exists and no
`harness.config` sits beside it, every entry point refuses to run and prints the `mv`. When both
exist, `harness.config` wins. Any value of `USE_GITHUB` other than `true` or `false` is refused,
so a typo can neither publish nor go silently local.

Every issue-aware command carries two backends. Local identifiers carry a `local-` prefix for two
reasons. A commit message pushed later never autolinks to an unrelated GitHub issue. Issue
resolution never reads the identifier as a GitHub number, because it already ignores
letters-dash-number tokens. Scaffold invariants S5 and S6 are reworded so they hold in either
backend, and S22 commits local mode to leaving nothing outside the machine.

> Raised by: `/grill` on local mode, 2026-10-15. See `.agents/specs/2026-10-15-local-mode.md`.
