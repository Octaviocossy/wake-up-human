# Command: supervise-epic

Execute the children of an **epic** — a GitHub issue, or in local mode (`USE_GITHUB=false`)
a local epic plan file — against a dedicated **epic integration
branch**, exactly like `/execute-epic`, but with a **human review gate** in front of
every merge: each child is pushed, passed through the agentic review, then presented to
you — diff, log, and report — for an explicit approve/reject decision before the runner
integrates it. Runs every runnable wave to completion in one invocation, then hands the
epic off: a **single `epic → main` pull request** in GitHub mode, a **printed `git push`**
(and a suggested `gh pr create`) in local mode. Re-running is idempotent.

`$ARGUMENTS` is **optional** and may combine an **epic argument** — `#<n>` or `<n>` in
GitHub mode; `local-<n>` or the path to the epic plan file in local mode
(`parallel-orchestration.md` › Selecting the Epic) — with `skip confirm` (skip step 7)
or `dry-run` (stop after step 7, printing the plan but not running the runner). Neither
argument skips the per-child review gate in step 8 — that decision is the entire point of
this command.

## Context injected by the wrapper

- **Harness mode** — the injected `sh .agents/scripts/harness-mode.sh` output: a `Mode:`
  line (`github`, `local` or `refused`), then `Remote: <url>` / `Remote: (none)`, or
  `Reason: <message>` when refused.
- **Current branch** — the injected `git rev-parse --abbrev-ref HEAD` output.

## User-invocable only

This command must never run inside a headless parallel-runner child
(`.agents/scripts/run-parallel-issues.sh`) — there is nobody there to answer the
per-child review gate in step 8, and an agent answering its own review would defeat the
entire purpose of a *human* review gate. This is the same boundary
`design-interrogation.md` draws around `/grill`:

| Agent | Enforcement |
|-------|-------------|
| Claude Code | `disable-model-invocation: true` in `.claude/commands/supervise-epic.md` — user-invoked only |
| OpenCode | No equivalent frontmatter field; this paragraph is the enforcement — never dispatch `/supervise-epic` from inside a headless run |

For unattended execution use `/execute-epic` instead — it runs the identical pipeline
but resolves every child with the agentic review alone, never a human.

## Instructions

Steps 1–7 and 9 are the same procedure `/execute-epic` follows —
`.agents/rules/parallel-orchestration.md` is the shared trunk both commands include.
Step 8 is where the two commands diverge: this command adds a human decision per child
before anything is integrated.

### 1 — Read the mode, owner/repo and current branch

State the active mode (`Mode: github` or `Mode: local`) as the first line of your reply,
before anything is written — even under `skip confirm`.

- `Mode: refused` → stop, relay the `Reason:` line verbatim, write nothing.
- `Mode: github` → extract `owner` and `repo` from the `Remote:` URL (HTTPS or SSH).
  `Remote: (none)` → stop: GitHub mode needs an `origin` (or set `USE_GITHUB=false` in
  `.agents/harness.config`).
- `Mode: local` → no owner/repo; for the rest of this command call no GitHub tool and
  run no `git fetch`, `git push` or other remote command. Remember whether `Remote:` was
  `(none)` for step 9.

Note the current branch.

### 2 — Resolve the epic

Take the epic argument from `$ARGUMENTS` (whatever is not `skip confirm` or `dry-run`)
and resolve it per `parallel-orchestration.md` › Selecting the Epic:

- *GitHub mode, argument given* — `mcp__github__issue_read` (`method: "get"`) on that
  number for `title` and `body`; refuse a pull request.
- *GitHub mode, no argument* — the precedence in `.agents/rules/issue-resolution.md`
  from the current branch (numeric segment, linked PR, title-slug, or ask), then
  `mcp__github__issue_read` (`method: "get"`) for `title` and `body`.
- *Local mode, argument given* — `sh .agents/scripts/local-issues.sh find local-<n>`
  (exit 1: no such local issue; exit 2: the ID is duplicated — stop and say which);
  for a path, read its `> Issue: #local-<n>` header and check `find` returns that same
  path. The file must match `*-epic-local-*.md`. Its H1 is the epic title and the whole
  file is the epic body.
- *Local mode, no argument* — the candidate listing in Selecting the Epic.
- A reference from the other backend is refused, naming the active mode.

### 3 — Find the epic plan

Search `.agents/plans/*.md` for a file whose header contains `> Issue: #<epic>`. If
found, use its `Children & Waves` table and edge list as the primary source of truth
(and its `> Integration branch:` header line, if present, per Step 5 below).

If no plan file exists, reconstruct the graph from GitHub:
1. Parse the epic body's child task-list for child issue numbers.
2. For each child, call `mcp__github__issue_read` (`method: "get"`) and extract the `> Depends on:` header.
3. Build the edge list from those dependencies.

If neither source yields a graph, ask the user to run `/spec-breakdown` first.

**Local mode.** The epic plan resolved in step 2 is the only source — there is no
GitHub reconstruction. Read its `## Children & Waves` table (Issue `#local-<n>`,
Branch, Title per row) and its `## Dependency Edges`; the edge list is primary and each
child plan's `> Depends on:` is the fallback, exactly as in GitHub mode. Resolve every
child's plan with `sh .agents/scripts/local-issues.sh find local-<n>`; a child whose
plan is missing (exit 1) or duplicated (exit 2) stops the command with that child named.
No table → ask the user to run `/spec-breakdown` first.

### 4 — Compute waves

Apply Kahn leveling from `.agents/rules/parallel-orchestration.md` (Wave / Frontier
Algorithm section): assign each child to a wave, ascending by issue number within each
wave. In local mode order by the number in `local-<n>`, numerically (`local-9` before
`local-10`). Apply the cycle guard; stop and report if a cycle is detected.

Display the full wave plan to the user.

### 5 — Derive the integration branch

Compute `EPIC_BRANCH = epic/<epic#>-<kebab-slug-of-epic-title>` (strip a leading
`epic:` from the title; kebab-case the rest; keep it under ~50 chars). This is derived
from the **epic issue**, independent of the branch the user invoked from. State it
explicitly in the plan display. If the epic plan file has a `> Integration branch:`
header, prefer that value (it was fixed at `/spec-breakdown` time). In local mode the epic
plan's `> Integration branch: epic/local-<n>-<slug>` header is authoritative; if it is
absent, derive `epic/local-<n>-<kebab-slug-of-title>` the same way.

### 6 — Determine per-child status against the epic branch

For each child, classify:

- **done** — the epic branch already contains its merge: a commit whose message
  **starts with** `Merge child #<child> (` (`parallel-orchestration.md` › Runnable
  frontier — never a substring match, which reads `#1` as done once `#12` merged).
  - *GitHub mode:* `mcp__github__list_commits { owner, repo, sha: "<EPIC_BRANCH>", per_page: 100 }`;
    if the call 404s (the epic branch does not exist yet), treat **all** children as
    not-done.
  - *Local mode:* `git show-ref --verify --quiet "refs/heads/<EPIC_BRANCH>" && git log --format=%s "refs/heads/<EPIC_BRANCH>" -- | grep -q '^Merge child #local-<n> ('`
    — exit 0 is done; no MCP, no fetch, no 100-commit cap. No local epic branch →
    **all** children not-done.
- **blocked (this session)** — appears in `.worktrees/.failed` or `.worktrees/.mergefail`
  after a run, or exhausted `MAX_REWORK_ROUNDS` under the review gate (step 8) — compare
  identifiers as whole fields (`grep -qx '<child>' .worktrees/.failed`), never substrings.
- **pending** — otherwise.

If every child is already done, skip to step 9 (the hand-off).

### 7 — Confirm

Unless `$ARGUMENTS` contains `skip confirm`, print and wait for explicit confirmation:

- The active **mode** — and, in local mode, that nothing leaves the machine (no GitHub
  call, no fetch, no push) and that step 9 only prints the push
- Epic title and number (local mode: its `local-<n>` ID and the epic plan path; each child
  shown with its plan path)
- The **integration branch** name (`EPIC_BRANCH`)
- Full wave plan (all waves, marking done/pending per child)
- The `AGENT_EXEC_CMD` and `REVIEW_AGENT_EXEC_CMD` that will be used
- `BASE_BRANCH` (local mode: a missing epic branch is cut from the **local** `BASE_BRANCH`,
  and the printed `gh pr create` targets it)
- Concurrency cap (`PARALLEL_MAX_CONCURRENCY`) and rework cap (`MAX_REWORK_ROUNDS`)
- A reminder that every child pauses for your decision at the review gate before it
  can integrate
- Any warnings (CLI not on PATH, children > `MAX_CHILDREN`, etc.)

If `$ARGUMENTS` contains `dry-run`, stop here after printing the plan — nothing is written:
no runner call, no GitHub write, no plan-file write.

### 8 — Wave loop (auto-advance, gated by human review)

Repeat until no progress:

1. Compute the **frontier** = pending children whose **every** dependency is **done**
   (merged into the epic branch).
2. If the frontier is empty **and** pending children remain, their dependencies failed,
   conflicted, or exhausted rework → report which children are blocked and why, then
   break the loop.
3. If the frontier is empty **and** no pending children remain → the epic is fully
   integrated → go to step 9.
4. **Push stage.** For each child in the frontier, write its issue body to
   `.worktrees/<branch>.issue.md` — fetch with `mcp__github__issue_read`
   (`method: "get"`). The implementing agent dispatched next has no GitHub access by
   design (Adapter Contract); without this file it falls back to "implement the issue
   body as described in #<child>", which it cannot do. The reviewer dispatched later
   reads the same file for its Spec axis — without it, the Spec axis would silently
   fall back to the plan file and miss a case where the issue and the plan diverged.
   Also write the epic issue's body (already fetched in step 2) once per session to
   `.worktrees/.epic-issue.md` — shared by every child. The reviewer passes it to the
   Spec axis for the child's intended scope; without it, the skill's "read the epic
   issue" instruction is a silent no-op headless (no GitHub access by design).

   **Local mode:** instead of `mcp__github__issue_read`, write each
   `.worktrees/<branch>.issue.md` as a byte-for-byte copy of the child's plan file
   (`cp <child plan> .worktrees/<branch>.issue.md`, or read it and write the identical
   content), and `.worktrees/.epic-issue.md` once per session as a copy of the epic plan
   file. These copies are the only way the agents see the issue: plan files are never
   committed, so the child worktree has none and the runner's own `> Issue:` lookup inside
   it finds nothing. Runner arguments carry the local ID —
   `"local-<n>:local-<n>-<slug>:<title>"`.

   Then invoke the runner with no action flag:
   ```sh
   sh .agents/scripts/run-parallel-issues.sh --epic <EPIC_BRANCH> \
     "<issue>:<branch>:<title>" "<issue>:<branch>:<title>" ...
   ```
   Wait for it to finish. Read `.worktrees/.pushed` (in local mode the runner commits
   without pushing and still lists the child there) and `.worktrees/.failed`
   (Runner Contract, plain-run outputs).
5. **Agentic review.** Invoke the runner's `--review` action over the pushed children:
   ```sh
   sh .agents/scripts/run-parallel-issues.sh --epic <EPIC_BRANCH> --review \
     "<issue>:<branch>:<title>" "<issue>:<branch>:<title>" ...
   ```
   This writes `.worktrees/<branch>.review.md` per child (the Standards + Spec report
   from `standards-and-spec-review`, run against `<EPIC_BRANCH>` as the fixed point);
   reads the `.worktrees/<branch>.issue.md` already written in the push stage above.
   A child that lands in `.worktrees/.failed` here — a review axis failed, timed out
   (`REVIEW_TIMEOUT`), or wrote nothing — is **blocked** (sub-step 11), not presented
   at the gate: a half-reviewed child must never be decided as if both axes had seen it.
6. **The review gate — one decision per child.** For each reviewed child, present:
   - Diffstat: `git -C .worktrees/<branch> diff --stat <EPIC_BRANCH>...HEAD`
   - Full diff: `git -C .worktrees/<branch> diff <EPIC_BRANCH>...HEAD`
   - The agent's implementation log: `.worktrees/<branch>.log`
   - The agentic review report: `.worktrees/<branch>.review.md`
   - **Pre-selection:** if the report contains a **hard violation**, pre-select
     "reject" with that violation's reason shown — you may still approve anyway. A
     **judgement call** never pre-selects anything; you weigh it yourself. (Severity
     definitions: `.agents/ubiquitous-language-scaffold.md` › Branch review.)

   Ask for an explicit **approve** or **reject** per child. On reject, ask for written
   feedback (may be left blank — the agentic report alone is still passed on).
7. **Rejected children → rework.** For each rejected child:
   - Count existing `rework(#<issue>): round <n>` commits on its branch (`git -C
     .worktrees/<branch> log --oneline --grep="^rework(#<issue>):"`) against
     `MAX_REWORK_ROUNDS`. If the cap is already reached (or `MAX_REWORK_ROUNDS=0`),
     the child is **blocked** — skip to the blocked handling below; do not rework it.
   - Otherwise, write `.worktrees/<branch>.feedback` = your written text (if any) plus
     the full contents of `.worktrees/<branch>.review.md`.
   - Invoke the runner's `--rework` action for the still-eligible rejected children in
     one call:
     ```sh
     sh .agents/scripts/run-parallel-issues.sh --epic <EPIC_BRANCH> --rework \
       "<issue>:<branch>:<title>" ...
     ```
   - A child that lands in `.worktrees/.failed` after `--rework` is **blocked** — the
     re-dispatch itself failed (agent/worktree/push failure).
   - Every other reworked child **returns to sub-step 5** (re-review) — the review
     re-runs every round, since a rework can break something the prior round approved.
8. **Approved children → integrate.** Once a child is approved (immediately, or after
   surviving rework and re-review), invoke the runner's `--integrate` action:
   ```sh
   sh .agents/scripts/run-parallel-issues.sh --epic <EPIC_BRANCH> --integrate \
     "<issue>:<branch>:<title>" ...
   ```
   Read `.worktrees/.merged` (integrated) and `.worktrees/.mergefail` (merge
   conflict — branch pushed but not integrated — in local mode nothing is pushed, so a
   `.mergefail` entry is always a real merge conflict).
9. **For each merged child:** *GitHub mode:* post a ship-note comment to the child issue
    (`mcp__github__add_issue_comment`, mirroring `/ship-note`: Summary, Files changed
    from `.worktrees/<branch>.log`, Validation, how many rework rounds ran and the last
    rejection reason if any, and the `#<child> → <EPIC_BRANCH>` integration reference);
    **close the child issue** (`mcp__github__issue_write`, `method: "update"`,
    `state: "closed"`, `state_reason: "completed"`) — the runner has already deleted
    its branch; then tick the epic task-list item (`mcp__github__issue_write`,
    `method: "update"`, `- [ ] #<child>` → `- [x] #<child>`, preserving the rest of the
    body).

    *Local mode:* append a `## Ship Note — <YYYY-MM-DD>` section to the end of the child's
    plan file with the same content — Summary, Files changed from
    `.worktrees/<branch>.log`, Validation, the `#local-<n> → <EPIC_BRANCH>` integration
    reference, and how many rework rounds ran with the last rejection reason quoted from
    `.worktrees/<branch>.review.md`. Count rounds on the local epic branch, with no
    fetch: `git log "refs/heads/<EPIC_BRANCH>" --oneline --grep "^rework(#local-<n>): round" --grep "^rework(#local-<n>): ronda" | grep -c .`
    Then rewrite the child plan's `> Status:` line to `> Status: **completed**` and its
    `> Updated:` line to today's date (the analogue of closing the issue), and set that
    child's Status cell in the epic plan's `## Children & Waves` table to `done` (the
    analogue of ticking the task list). The runner has already deleted the child's local
    branch unless `KEEP_CHILD_BRANCHES=1`. Commit neither file.

    Either mode: mark the child **done** in this session's state.
10. **For each `.mergefail` child, offer guided recovery** — a merge conflict is an
    integration problem, never a rework trigger (Edges, decision 16). The runner
    retains the child's worktree at `.worktrees/<branch>/` and its log. Ask the user
    whether to resolve now. On yes, merge the epic branch **into the child** — this
    reproduces the same conflict in the child's direction, where resolving it is safe:
    - *GitHub mode:* `git -C .worktrees/<branch> fetch origin <EPIC_BRANCH>` then
      `git -C .worktrees/<branch> merge origin/<EPIC_BRANCH>`;
    - *Local mode:* `git -C .worktrees/<branch> merge <EPIC_BRANCH>` — the local epic
      branch, no fetch.

    The `resolving-merge-conflicts` skill takes over from there and concludes the merge in
    the child worktree. Present the resolved diff for review (push nothing yourself — the
    runner does every push there is, none in local mode), then loop back to this wave's
    `--integrate` call so the runner integrates it. **Never** write to `<EPIC_BRANCH>`.
    On no, leave the child blocked.
11. **For each blocked child** (rework cap exhausted, or `--rework`/`--review` itself
    failed): *GitHub mode:* post a comment noting the cause and that
    `.worktrees/<branch>.log` (and `.review.md`, if present) are retained. **Do not** tick
    the task-list. Its dependents stay blocked.

    *Local mode:* append a `## Failure — <YYYY-MM-DD>` section to the child's plan with the
    same content, and set its Status cell in the epic table to `blocked`; leave its
    `> Status:` line alone. Its dependents stay blocked.
12. If this iteration merged **zero** children, break (no-progress guard) to avoid
    looping forever. Bound the loop to at most the number of waves.

### 9 — Hand the epic off and record the final summary

*GitHub mode* — open the single epic PR and post the final summary:

- **Reconcile done children (self-heal).** For every child classified **done**, make sure
  its GitHub issue is closed: fetch the still-open set once with
  `mcp__github__list_issues { owner, repo, state:"open" }` and, for any done child still in
  it, `mcp__github__issue_write` (`method:"update"`, `state:"closed"`,
  `state_reason:"completed"`). This catches children merged in a prior/interrupted run or
  before per-child closing existed. **Do not** touch child branches here — branch lifecycle
  is the runner's (it honors `KEEP_CHILD_BRANCHES`). **Never** close the **epic** issue —
  it closes when the `epic → main` PR merges.
- If **all** children are done: ensure a PR exists for the epic branch —
  `mcp__github__list_pull_requests { head:"<owner>:<EPIC_BRANCH>", state:"all" }`; if
  none, `mcp__github__create_pull_request { owner, repo, head:"<EPIC_BRANCH>",
  base:"main", title:"<epic title>", body:"Closes #<epic>\n\nIntegrates all child
  issues:\n<child table>" }`.
- Post a final summary comment on the epic (`mcp__github__add_issue_comment`) with the
  child → status table (including rework-round counts per child) and the epic PR URL.
- If some children are blocked: **do not** open the epic PR; report the blocked set and
  stop (re-running `/supervise-epic` after the human resolves the blockage is
  idempotent — already-merged children are detected as done in step 6).

*Local mode* — no GitHub call and no remote command:

- **Reconcile done children (self-heal).** For every child classified **done** whose
  plan does not read `> Status: **completed**`, set it (and `> Updated:`) and set its
  epic table cell to `done` — this catches children integrated by an interrupted run. No
  ship-note is written here. Do not touch child branches (the runner's), and never change
  the epic plan's own `> Status:` — the user does, once the epic reaches `BASE_BRANCH`
  (the analogue of the epic issue closing when its PR merges).
- If **all** children are done: append `## Epic Summary — <YYYY-MM-DD>` to the epic plan
  — the child → status table with rework-round counts, and the integration branch —
  unless an Epic Summary already in the file records every child done (a re-run then
  appends nothing). Then **print, and never run**:
  ```
  git push -u origin <EPIC_BRANCH>
  gh pr create --base <BASE_BRANCH> --head <EPIC_BRANCH> --title "<epic title>" --body-file <epic plan path>
  ```
  There is no `Closes` line — no GitHub issue corresponds to a local epic. If step 1
  saw `Remote: (none)`, say first that the repository has no `origin` and that one must
  be added (`git remote add origin <url>`) before pushing. Remind the user the plan files
  are uncommitted and theirs to commit.
- If some children are blocked: print nothing to push; report the blocked set and stop
  (re-running is idempotent — integrated children are detected as done in step 6).

## Rules

- Resolve the epic per `parallel-orchestration.md` › Selecting the Epic; only GitHub mode
  without an epic argument falls back to `issue-resolution.md` and the current branch.
- Follow `parallel-orchestration.md` for wave computation, the epic integration branch,
  the Runner Contract, the review gate, and the rework loop.
- The runner integrates each child into the epic branch; the agent never merges — it
  only reads epic-branch state (`mcp__github__list_commits` in GitHub mode, `git log` on
  the local ref in local mode) and hands the epic off — the final PR in GitHub mode, a
  printed push in local mode (S5).
- **Every child passes through the review gate before it can integrate.** There is no
  path in this command that calls `--integrate` on a child that has not been approved
  by an explicit human decision this session.
- A hard violation in the agentic review pre-selects "reject"; a judgement call never
  does. Either way the human decision is final — the report informs it, it never
  substitutes for it.
- A rejection triggers rework (up to `MAX_REWORK_ROUNDS`); a merge conflict at
  integration time never does — it goes to guided recovery in the child's direction.
- Waves auto-advance in a single run: the wave loop keeps invoking the runner on the
  newly-runnable frontier until the epic is complete or blocked. Within a wave, the
  loop does not advance to the next wave until every child in the current one is either
  integrated or blocked — approved children are not held back by a sibling still in
  rework, but the wave itself is not "done" until all of its children resolve one way
  or the other.
- Re-running is idempotent — done children are detected from the epic branch; only
  pending children in the current frontier run; rework round counts are re-derived from
  git commits, never stored.
- Never push or commit directly; the runner handles that. The agent never writes to the
  epic branch.
- In local mode, never call a GitHub tool and never run `git fetch`, `git push` or `gh` —
  the hand-off is printed, never executed — and never commit the plan files this command
  writes (spec decisions 2, 9, 17).
- `dry-run` stops after printing the plan (step 7); no runner call, no GitHub writes, no
  plan-file writes. Neither `dry-run` nor `skip confirm` skips the per-child review gate
  in step 8.
- In GitHub mode, one `epic → main` PR at completion — no per-child PRs. Per-child
  traceability comes from ship-note comments (including rework-round counts) and epic
  task-list ticking. In local mode the same records are dated sections in the plan files
  (`local-mode.md` › Executing a local epic).
- On clean integration each child is **closed** (agent, `issue_write` → `state:"closed"`,
  `state_reason:"completed"`) and its **branch deleted** (runner, unless
  `KEEP_CHILD_BRANCHES=1`) — in local mode its plan's `> Status:` becomes `completed` and
  the runner deletes its **local** branch. The **epic** issue and the **epic branch** are
  never closed/deleted by this flow — the epic closes via the `epic → main` PR's
  `Closes #<epic>` (in local mode the epic plan's `> Status:` is the user's to change).
- Never invoke this command, and never let it be invoked, from inside a headless
  parallel-runner child — see User-invocable only, above.
