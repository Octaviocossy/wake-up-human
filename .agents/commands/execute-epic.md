# Command: execute-epic

Execute the children of an **epic** — a GitHub issue, or in local mode (`USE_GITHUB=false`)
a local epic plan file — against a dedicated **epic integration
branch**. Each child runs the full staged pipeline — push, agentic review, automatic
rework on a hard violation, integrate — with nobody watching: a hard violation blocks
integration and triggers rework instead of a prompt; a judgement call never blocks.
Waves still advance with no manual merge step. Runs every runnable wave to completion
in one invocation, then hands the epic off: a **single `epic → main` pull request** in
GitHub mode, a **printed `git push`** (and a suggested `gh pr create`) in local mode.
Re-running is idempotent.

`$ARGUMENTS` is **optional** and may combine an **epic argument** — `#<n>` or `<n>` in
GitHub mode; `local-<n>` or the path to the epic plan file in local mode
(`parallel-orchestration.md` › Selecting the Epic) — with `skip confirm` (skip step 7)
or `dry-run` (stop after step 7, printing the plan but not running the runner).

## Context injected by the wrapper

- **Harness mode** — the injected `sh .agents/scripts/harness-mode.sh` output: a `Mode:`
  line (`github`, `local` or `refused`), then `Remote: <url>` / `Remote: (none)`, or
  `Reason: <message>` when refused.
- **Current branch** — the injected `git rev-parse --abbrev-ref HEAD` output.

## Instructions

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
- **failed/conflict (this session)** — appears in `.worktrees/.mergefail` or
  `.worktrees/.failed` after a run (used during the wave loop, step 8) — compare
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
- That each child now runs push → agentic review → automatic rework on a hard violation
  → integrate before it lands on `EPIC_BRANCH` (the review gate — no prompt on this path)
- The `AGENT_EXEC_CMD` that will implement each child and the `REVIEW_AGENT_EXEC_CMD`
  that will review it (inherits `AGENT_EXEC_CMD` when unset)
- `BASE_BRANCH` (local mode: a missing epic branch is cut from the **local** `BASE_BRANCH`,
  and the printed `gh pr create` targets it)
- Concurrency cap (`PARALLEL_MAX_CONCURRENCY`) and the rework cap (`MAX_REWORK_ROUNDS`)
- Any warnings (CLI not on PATH, children > `MAX_CHILDREN`, etc.)

If `$ARGUMENTS` contains `dry-run`, stop here after printing the plan — nothing is written:
no runner call, no GitHub write, no plan-file write.

### 8 — Wave loop (auto-advance)

Repeat until no progress:

1. Compute the **frontier** = pending children whose **every** dependency is **done**
   (merged into the epic branch).
2. If the frontier is empty **and** pending children remain, their dependencies failed
   or conflicted → report which children are blocked and why, then break the loop.
3. If the frontier is empty **and** no pending children remain → the epic is fully
   integrated → go to step 9.
4. **Push stage.** For each child in the frontier, write its issue body to
   `.worktrees/<branch>.issue.md` — fetch with `mcp__github__issue_read`
   (`method: "get"`). The implementing agent dispatched next has no GitHub access by
   design (Adapter Contract); without this file it falls back to "implement the issue
   body as described in #<child>", which it cannot do. The reviewer dispatched later
   reads the same file for its Spec axis. Also write the epic issue's body (already
   fetched in step 2) once per session to `.worktrees/.epic-issue.md` — shared by every
   child. The reviewer passes it to the Spec axis for the child's intended scope;
   without it, the skill's "read the epic issue" instruction is a silent no-op headless
   (no GitHub access by design).

   **Local mode:** instead of `mcp__github__issue_read`, write each
   `.worktrees/<branch>.issue.md` as a byte-for-byte copy of the child's plan file
   (`cp <child plan> .worktrees/<branch>.issue.md`, or read it and write the identical
   content), and `.worktrees/.epic-issue.md` once per session as a copy of the epic plan
   file. These copies are the only way the agents see the issue: plan files are never
   committed, so the child worktree has none and the runner's own `> Issue:` lookup inside
   it finds nothing. Runner arguments carry the local ID —
   `"local-<n>:local-<n>-<slug>:<title>"`.

   Then invoke the runner once for the frontier,
   no action flag (a plain run — it pushes each child and does not integrate):
   ```sh
   sh .agents/scripts/run-parallel-issues.sh --epic <EPIC_BRANCH> \
     "<issue>:<branch>:<title>" "<issue>:<branch>:<title>" ...
   ```
   Read `.worktrees/.pushed` (ready for review — in local mode the runner commits without
   pushing and still lists the child there) and `.worktrees/.failed` (agent/
   worktree/push failure — blocked immediately; rework is for a rejected review, not a
   run that never produced a working push).
5. **Review → decide → rework cycle**, over the children in `.worktrees/.pushed`.
   Repeat the three steps below until every one of them is either **approved** or
   **blocked**:
   1. **Review stage** — one `--review` call for every still-unresolved child:
      ```sh
      sh .agents/scripts/run-parallel-issues.sh --epic <EPIC_BRANCH> --review \
        "<issue>:<branch>:<title>" ...
      ```
      Writes `.worktrees/<branch>.review.md` (the agentic Standards + Spec report) per
      child; reads the `.worktrees/<branch>.issue.md` already written in the push stage
      above. A child that lands in `.worktrees/.failed` here — a review axis failed,
      timed out (`REVIEW_TIMEOUT`), or wrote nothing — is **blocked**, exactly like a
      plain-run failure: its `.review.md` marks the axis that did not report, and an
      unreviewed child never reaches the decide step. Drop it from the unresolved set.
   2. **Decide** — read each child's `.review.md`. Any finding explicitly marked a
      **hard violation** (Standards or Spec axis) → **reject** it. Otherwise (judgement
      calls only, or no findings) → **approve** it. This is the whole authority the
      auto path has — judgement calls never block (`parallel-orchestration.md` › The
      Review Gate; `.agents/ubiquitous-language-scaffold.md` › Branch review).
   3. **Rework stage** — for every rejected child, write `.worktrees/<branch>.feedback`
      with the full review report (no human text on this path — there is nobody to add
      any) and call:
      ```sh
      sh .agents/scripts/run-parallel-issues.sh --epic <EPIC_BRANCH> --rework \
        "<issue>:<branch>:<title>" ...
      ```
      A child with rounds left under `MAX_REWORK_ROUNDS` gets a new
      `rework(#<child>): round <n>` commit and goes back to the review stage above for
      **re-review** — a rework can break something the previous round passed. A child
      whose rework attempt itself fails, or that already exhausted its rounds, lands in
      `.worktrees/.failed` and is **blocked** exactly like a mergefail; drop it from the
      unresolved set. The runner counts rounds from git (`rework(#N): round K` commits
      already on the branch), so this cycle is bounded without any state kept here.
6. **Integrate stage.** For every approved child:
   ```sh
   sh .agents/scripts/run-parallel-issues.sh --epic <EPIC_BRANCH> --integrate \
     "<issue>:<branch>:<title>" ...
   ```
   Read `.worktrees/.merged` (integrated) and `.worktrees/.mergefail` (conflict —
   branch pushed but not integrated — in local mode nothing is pushed, so a `.mergefail`
   entry is always a real merge conflict).
7. **For each merged child:** *GitHub mode:* post a ship-note comment to the child issue
   (`mcp__github__add_issue_comment`, mirroring `/ship-note`: Summary, Files changed
   from `.worktrees/<branch>.log`, Validation, and the `#<child> → <EPIC_BRANCH>`
   integration reference) **plus** how many rework rounds ran and, if any ran, the last
   hard-violation reason — count rounds with `git fetch origin <EPIC_BRANCH>` then
   `git log origin/<EPIC_BRANCH> --grep "^rework(#<child>): round"
   --grep "^rework(#<child>): ronda" --oneline` (two `--grep` flags are ORed, so the
   pre-rename spelling still counts), and quote
   the reason from `.worktrees/<branch>.review.md` (no comment is posted per rejection;
   this ship-note is the only trace). **Close the child issue**
   (`mcp__github__issue_write`, `method: "update"`, `state: "closed"`,
   `state_reason: "completed"`) — the runner has already deleted its branch; then tick
   the epic task-list item (`mcp__github__issue_write`, `method: "update"`,
   `- [ ] #<child>` → `- [x] #<child>`, preserving the rest of the body).

   *Local mode:* append a `## Ship Note — <YYYY-MM-DD>` section to the end of the child's
   plan file with the same content — Summary, Files changed from
   `.worktrees/<branch>.log`, Validation, the `#local-<n> → <EPIC_BRANCH>` integration
   reference, and how many rework rounds ran with the last hard-violation reason quoted
   from `.worktrees/<branch>.review.md`. Count rounds on the local epic branch, with no
   fetch: `git log "refs/heads/<EPIC_BRANCH>" --oneline --grep "^rework(#local-<n>): round" --grep "^rework(#local-<n>): ronda" | grep -c .`
   Then rewrite the child plan's `> Status:` line to `> Status: **completed**` and its
   `> Updated:` line to today's date (the analogue of closing the issue), and set that
   child's Status cell in the epic plan's `## Children & Waves` table to `done` (the
   analogue of ticking the task list). The runner has already deleted the child's local
   branch unless `KEEP_CHILD_BRANCHES=1`. Commit neither file.

   Either mode: mark the child **done** in this session's state.
8. **For each blocked child** — agent/push failure, exhausted rework, or mergefail —
   *GitHub mode:* post a failure comment (`mcp__github__add_issue_comment`) noting the cause (quoting
   the last review verdict when the cause was a rejection, or the merge conflict with
   `<EPIC_BRANCH>`) and that `.worktrees/<branch>.log` / `.worktrees/<branch>.review.md`
   are retained. **Do not** tick the task-list. Its dependents stay blocked.

   *Local mode:* append a `## Failure — <YYYY-MM-DD>` section to the child's plan with the
   same content, and set its Status cell in the epic table to `blocked`; leave its
   `> Status:` line alone. Its dependents stay blocked.
9. **For each `.mergefail` child, offer guided recovery.** The runner retains the child's
   worktree at `.worktrees/<branch>/` and its log. Ask the user whether to resolve now. On
   yes, merge the epic branch **into the child** — this reproduces the same conflict in
   the child's direction, where resolving it is safe:
   - *GitHub mode:* `git -C .worktrees/<branch> fetch origin <EPIC_BRANCH>` then
     `git -C .worktrees/<branch> merge origin/<EPIC_BRANCH>`;
   - *Local mode:* `git -C .worktrees/<branch> merge <EPIC_BRANCH>` — the local epic
     branch, no fetch.

   The `resolving-merge-conflicts` skill takes over from there and concludes the merge in
   the child worktree. Present the resolved diff for review, then re-run `/execute-epic` so
   the runner integrates it (a re-run replays the review → rework → integrate stages for
   it, since the epic branch has no merge for it yet). Push nothing yourself — the runner
   does every push there is (none in local mode) — and **never** write to
   `<EPIC_BRANCH>`. On no, leave the child blocked.
10. If this iteration integrated **zero** children, break (no-progress guard) to avoid
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
  child → status table and the epic PR URL.
- If some children failed/conflicted: **do not** open the epic PR; report the blocked
  set and stop (re-running `/execute-epic` after the human fixes the conflict is
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
  the review gate, the rework loop, and the runner invocation.
- Every child passes an **agentic review** (the runner's `--review` action, a fresh
  headless invocation under `REVIEW_AGENT_EXEC_CMD` — never the agent that wrote the
  code) before it can integrate, and this repeats on every rework round. A **hard
  violation blocks integration and triggers automatic rework**; a **judgement call
  never blocks** and lands only in the ship-note. There is no human on this path, so
  the hard-violation/judgement-call split is the only thing that decides.
- The runner is invoked in pipeline order — plain run → `--review` → `--rework`
  (as needed) → `--integrate` — and is the epic branch's sole writer throughout; the
  agent never merges, it only reads epic-branch state (`mcp__github__list_commits` in
  GitHub mode, `git log` on the local ref in local mode), drives the runner's actions, and
  hands the epic off — the final PR in GitHub mode, a printed push in local mode (S5).
- Waves auto-advance in a single run: the wave loop keeps invoking the runner on the
  newly-runnable frontier until the epic is complete or blocked.
- Re-running is idempotent — done children are detected from the epic branch; only
  pending children in the current frontier run.
- Never push or commit directly; the runner handles that.
- In local mode, never call a GitHub tool and never run `git fetch`, `git push` or `gh` —
  the hand-off is printed, never executed — and never commit the plan files this command
  writes (spec decisions 2, 9, 17).
- The agent never writes to the epic branch. A merge conflict at `--integrate` time is
  resolved in the **child branch's** direction (merge `<EPIC_BRANCH>` into the child, per
  the `resolving-merge-conflicts` skill) and re-integrated by the runner on the next
  run — never routed into the rework loop, which is for "this is not what was asked
  for," not for an integration conflict.
- `dry-run` stops after printing the plan (step 7); no runner call, no GitHub writes, no
  plan-file writes.
- In GitHub mode, one `epic → main` PR at completion — no per-child PRs. Per-child
  traceability comes from ship-note comments (including rework-round count and last
  reason) and epic task-list ticking. No comment is posted per rejection — only the final
  ship-note. In local mode the same records are dated sections in the plan files
  (`local-mode.md` › Executing a local epic).
- On clean integration each child is **closed** (agent, `issue_write` → `state:"closed"`,
  `state_reason:"completed"`) and its **branch deleted** (runner, unless
  `KEEP_CHILD_BRANCHES=1`) — in local mode its plan's `> Status:` becomes `completed` and
  the runner deletes its **local** branch. The **epic** issue and the **epic branch** are
  never closed/deleted by this flow — the epic closes via the `epic → main` PR's
  `Closes #<epic>` (in local mode the epic plan's `> Status:` is the user's to change).
