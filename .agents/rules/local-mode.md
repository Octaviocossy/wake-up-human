# Rule: Local Mode

**Local mode** runs the issue and epic workflow without GitHub. It is selected per machine by
`USE_GITHUB=false` in `.agents/harness.config`; the reasoning is in
`.agents/adr/0023-local-mode-is-a-harness-config-knob.md`. In local mode, issues and epics are
plan files under `.agents/plans/`, branches and worktrees stay on this machine, and the developer
decides when to push. With `USE_GITHUB` unset, empty or `true`, every command behaves as it does
in GitHub mode.

This file is the single reference for local mode. Every command that honors the mode
`@`-imports it and follows the backend its wrapper's `Mode:` line names.

---

## The switch

- **Where.** `USE_GITHUB` in `.agents/harness.config`, the per-machine, gitignored config
  (renamed from `.agents/parallel.config`). Scripts resolve it through
  `.agents/scripts/harness-config.sh` (`harness_config_load`); slash-command wrappers inject
  `sh .agents/scripts/harness-mode.sh`.
- **Values.** Unset or empty means `true`. Exactly `true` selects GitHub mode and exactly
  `false` selects local mode. Any other value is refused and named, so a typo can neither
  publish to GitHub nor go silently local.
- **The old file name.** When only `.agents/parallel.config` exists, every entry point refuses
  and prints the `mv` to `.agents/harness.config`. When both exist, `.agents/harness.config`
  wins and `.agents/parallel.config` is ignored.
- **What a wrapper injects.** Two lines: `Mode: github`, `Mode: local` or `Mode: refused`; then
  `Remote: <origin URL>` or `Remote: (none)` — or, after `Mode: refused`, `Reason: <message>`.
- **Legibility.** Every command states the active mode to the user before it writes anything.
  On `Mode: refused` it writes nothing, relays the `Reason:` line, and stops.
- **One backend per epic.** An epic lives entirely in the backend that created it. Switching
  modes in the middle of an epic, and mixing backends within one, are not supported.

---

## Nothing leaves the machine

In local mode no harness command calls a GitHub API — no `mcp__github__*` tool and no `gh` —
and none reads or writes a remote: no `git fetch`, `pull`, `push`, `ls-remote` or
`push --delete` (S22).

That is scaffold invariant **S22** (`.agents/ubiquitous-language-invariants-scaffold.md`): a breach is a hard violation at the review gate.

Reading `git remote get-url origin` reads `.git/config`, not the remote, and stays allowed. The
epic branch is cut from the local `BASE_BRANCH`; when an epic is done, the epic commands print the
`git push` and a suggested `gh pr create` for the developer to run.

Two harness entry points outside the issue and epic workflow have no local form, so they refuse
instead, before their first GitHub call, naming `USE_GITHUB=true` in `.agents/harness.config` as
the fix: `/handoff with-github` (a `/handoff` without it is unchanged), and
`.agents/scripts/sync-labels.sh` (exit `4`).

---

## Local issues

A **local issue** stands in for a GitHub issue, epic, or epic child. It is a plan file under
`.agents/plans/` whose header carries `> Issue: #local-<n>`. A plan without that line is only a
plan: nothing resolves to it or lists it.

| Kind | File |
|------|------|
| Stand-alone issue or epic child | `.agents/plans/<yyyy-mm-dd>-local-<n>-<slug>.md` |
| Epic | `.agents/plans/<yyyy-mm-dd>-epic-local-<n>-<slug>.md` |

The ID in the file name is for a human reading a directory listing. Resolution reads the
header, never the file name, and a file is never renamed after it is written — not even when
its title changes.

**Header**, in this order, before the first `## ` section:

```markdown
# <title>

> Issue: #local-<n>
> Status: **draft**
> Created: YYYY-MM-DD
> Updated: YYYY-MM-DD
```

- Nothing follows the ID on the `> Issue:` line: the runner and `local-issues.sh find` match the
  whole line.
- `> Status:` is one of `draft`, `in-progress`, `completed`, `abandoned`.
- An epic child adds `> Epic: #local-<m>` and, when it has dependencies,
  `> Depends on: #local-<a>, #local-<b>`.
- An epic adds `> Integration branch: epic/local-<n>-<slug>`.

**Body.** The `/create-issue` house style, unchanged: Goal, Context, Affected Files,
Step-by-Step Implementation, Architecture Decisions, Acceptance Criteria, Open Questions. Every
consumer — `/execute-issue`, the runner's prompt, the Spec axis — is written against it. A
local issue carries no labels.

---

## Identifiers

- **Shape.** `local-<n>`, written `#local-<n>` wherever a GitHub issue would be written
  `#<n>`. One sequence covers epics, children and stand-alone issues, and an ID is unique across
  the repository.
- **Allocation.** The next ID is 1 + the highest `<n>` in any `> Issue: #local-<n>` header in
  `.agents/plans/*.md`, in any commit message on any ref (`git log --all`), and in any local
  branch name. Allocate only through `sh .agents/scripts/local-issues.sh next-ids <k>`,
  immediately before writing the files. An ID is never reused: an integrated epic is an
  ancestor of the next one, so a reused ID would read as already merged.
- **Why the prefix.** A commit message pushed later never autolinks `#local-3` to an unrelated
  GitHub item `#3`, and GitHub-mode resolution ignores letters-dash-number tokens
  (`.agents/rules/issue-resolution.md`, precedence #1), so it never reads `local-3` as issue 3.
- **Branches.** `local-<n>-<slug>` for a stand-alone issue or an epic child;
  `epic/local-<n>-<slug>` for an epic's integration branch.
- **Commit markers.** The GitHub-mode shapes with the local ID: `feat(#local-<n>): …`,
  `rework(#local-<n>): round <k>`, `Merge child #local-<n> (<branch>) into <epic>`. Waves
  are ordered by `<n>`.

---

## The helper: `local-issues.sh`

`.agents/scripts/local-issues.sh` is the one place that scans for local issues. It only reads:
it never writes a plan, never commits, and never touches a remote.

| Subcommand | Prints | Exit status |
|------------|--------|-------------|
| `next-ids <k>` | `<k>` fresh consecutive IDs, one per line | 0; 3 on a malformed `<k>` |
| `find <local-n>` | the path of the one plan whose header line is exactly `> Issue: #local-<n>` | 0 found; 1 none; 2 more than one (paths on stderr); 3 malformed ID |
| `list [--open] [--epics]` | TSV `<id>`, `<status>`, `<path>`, `<title>`, ordered by `<n>`; `--open` drops `completed` and `abandoned`; `--epics` keeps only `*-epic-local-*.md` | 0; 3 on an unknown option |

It reads the plans of the checkout it runs in, which is the checkout the commands write them to.

---

## Resolution

A local-mode command maps the current branch to its local issue with the local-mode precedence
in `.agents/rules/issue-resolution.md`. It takes the branch's leading `local-<n>` segment and
looks it up with `local-issues.sh find`; otherwise it lists the open local issues and asks the
user. There is no MCP call, no `gh`, and no fuzzy title match.

---

## Local records

What GitHub mode writes to an issue, local mode writes to the plan file. A record is a dated
section appended at the end of the relevant plan file, after every earlier record:

| GitHub mode | Local mode |
|-------------|------------|
| Ship-note comment | `## Ship Note — YYYY-MM-DD` |
| `/comment-issue` comment | `## Comment — YYYY-MM-DD` |
| Failure comment | `## Failure — YYYY-MM-DD` |
| Final epic summary | `## Epic Summary — YYYY-MM-DD` |
| Close the child issue | Rewrite its `> Status:` to `**completed**` and bump `> Updated:` |
| Tick the epic's task list | Set that child's Status cell to `done` (or `blocked`) in the epic's `## Children & Waves` table |
| Labels | None |

Nothing reads a record back to decide what stage work is at. Execution state is derived from
git, as in GitHub mode (S6); a record is an artifact, like a review report (S12).
`local-issues.sh list --open` reads `> Status:` only to shorten a list a human chooses from.
`/update-issue` preserves every record verbatim.

---

## Plan files are never committed by a command

No command commits a local issue, a local epic, or a record appended to either — the same rule
that holds for every plan file. The developer commits them when they choose. Children never need
them in their worktree: the issue body reaches the headless agent and the reviewers through
`.worktrees/<branch>.issue.md`, and the epic body through `.worktrees/.epic-issue.md`, both
copied from the plan files. The epic branch stays the runner's alone (S5).

---

## Local epics

A **local epic** is a local issue whose plan file also carries the epic's dependency graph. It
stands in for a GitHub epic and its child issues, so nothing in it is a GitHub issue and
nothing in it is committed. `/spec-breakdown` writes the epic file and one plan file per child
in a single pass, with IDs from one `sh .agents/scripts/local-issues.sh next-ids <k>` call
(`<k>` = 1 + the number of children). The epic takes the first ID, and the children take the
rest in wave order. The header rules of Local issues apply to every file below.

### Epic file

`.agents/plans/<yyyy-mm-dd>-epic-local-<n>-<slug>.md`. `local-issues.sh list --epics` and
the epic pickers of `/execute-epic` and `/supervise-epic` match on the `-epic-` marker.

````markdown
# epic: <short title>

> Issue: #local-<n>
> Status: **draft**
> Created: YYYY-MM-DD
> Updated: YYYY-MM-DD
> Integration branch: epic/local-<n>-<slug>

## Goal
<1–2 sentences>. Design: `<spec path>`.

## Children & Waves

| Wave | Issue | Branch | Title | Status |
|------|-------|--------|-------|--------|
| 1 | #local-<a> | `local-<a>-<slug>` | <title> | pending |
| 2 | #local-<b> | `local-<b>-<slug>` | <title> | pending |

## Dependency Edges

```
local-<b> -> local-<a>
```

## ADRs Raised

- `.agents/adr/NNNN-<slug>.md`: <title>

---
*Generated by `/spec-breakdown` in local mode. Tracking epic: do not implement here. Run `/execute-epic local-<n>`.*
````

- **Title.** The H1 is the title a GitHub epic issue would carry, `epic: <short title>`. The
  duplicate guard compares it, and `<slug>` is that title without the `epic:` prefix.
- **`> Integration branch:`** names the epic integration branch, `epic/local-<n>-<slug>`.
  The epic commands read it rather than derive it. The runner creates the branch from the
  local `BASE_BRANCH` on first use, and no command ever pushes it. The user pushes it when
  they choose.
- **`## Children & Waves`** replaces the GitHub epic's task-list and its ` ```waves ` block.
  A child's Status is `pending` at creation. The epic commands set it to `done` when the
  child integrates, or to `blocked`; this is "ticking the epic". The column is a record, not
  state: whether a child is done is always derived from the epic branch's
  `Merge child #local-<n> (` commits and is never read back from the table (S6, S12).
- **`## Dependency Edges`** holds one `local-<child> -> local-<dependency>` per line.
- **`## ADRs Raised`** is present only when the breakdown came from a settled spec that
  raised ADRs.

### Child files

`.agents/plans/<yyyy-mm-dd>-local-<n>-<slug>.md`, worked on the branch `local-<n>-<slug>`,
which uses the same slug. The body is the full `/create-issue` house style, unchanged.

````markdown
# feat: <slice title>

> Issue: #local-<n>
> Status: **draft**
> Created: YYYY-MM-DD
> Updated: YYYY-MM-DD
> Epic: #local-<epic>
> Depends on: #local-<a>, #local-<b>

## Goal
## Context
## Affected Files
## Step-by-Step Implementation
## Architecture Decisions
## Acceptance Criteria
## Open Questions

---
*Generated by `/spec-breakdown` in local mode. Child of epic #local-<epic>, implemented by `/execute-epic local-<epic>`.*
````

Omit `> Depends on:` for a child with no dependency. Nothing may follow the ID on the
`> Issue:` line, because the runner's lookup is anchored.

### Graph sources

The graph has two sources, both local: the epic file, which is machine-primary, and the
children's `> Epic:` / `> Depends on:` headers. There is no GitHub fallback. If the epic file
is missing, rebuild the graph from the plan files whose header reads `> Epic: #local-<n>`. If
those are missing too, ask the user.

### Executing a local epic

`/execute-epic` and `/supervise-epic` (and `/spec`, in its execution phase) run a local
epic through the same pipeline as a GitHub one (S8); only the tracker and the hand-off
change.

- **Selecting it.** `local-<n>` or the epic plan's path; with no argument, the open
  epics that still have an unintegrated child (`parallel-orchestration.md` › Selecting
  the Epic).
- **What the headless agents read.** Plan files are never committed, so a child worktree
  cut from the epic branch has no copy of them. Before the plain run the command copies
  each child plan byte for byte to `.worktrees/<branch>.issue.md`, and the epic plan to
  `.worktrees/.epic-issue.md` — the same two files a GitHub run fills from issue bodies.
- **Done and rework.** A child is done when the local epic branch has a commit whose
  subject starts with `Merge child #local-<n> (` (`parallel-orchestration.md` › Runnable
  frontier). Rework rounds are counted from the local epic branch's
  `rework(#local-<n>): round <k>` commits. Nothing is ever fetched.
- **Records written** (formats: Local records, above):

  | Event | Child plan | Epic plan |
  |-------|------------|-----------|
  | Child integrated | `## Ship Note — <date>` appended; `> Status: **completed**`; `> Updated:` bumped | that child's Status cell → `done` |
  | Child blocked (agent, review or rework failure, exhausted rework, merge conflict) | `## Failure — <date>` appended | that child's Status cell → `blocked` |
  | Every child integrated | — | `## Epic Summary — <date>` appended once |

  A child found already integrated by an earlier run gets its Status and cell set, with
  no new ship-note. The epic plan's own `> Status:` is left to the user, just as the epic
  issue stays open in GitHub mode until its PR merges.
- **The hand-off.** Once every child is integrated, the command prints, and never runs:

  ```sh
  git push -u origin <epic branch>
  gh pr create --base <BASE_BRANCH> --head <epic branch> --title "<epic title>" --body-file <epic plan path>
  ```

  There is no `Closes` line: no GitHub issue corresponds to a local epic. When the
  repository has no `origin`, the command says so first.
- **Merge conflicts.** Guided recovery merges the **local** epic branch into the child
  (`git -C .worktrees/<branch> merge <epic branch>`), with no fetch.

---

## Cross-agent applicability

| Agent | Enforcement mechanism |
|-------|-----------------------|
| Claude Code | `@.agents/rules/local-mode.md` in the wrapper of every command that honors the mode |
| OpenCode | The same wrapper bodies, identical to Claude Code's (`command-creation.md`) |
