# Command: execute-issue

Execute the implementation described in the **current branch's** issue, in three explicit
phases: **Confirmation → Execution → Review**. The issue is a GitHub issue or — in local mode
(`USE_GITHUB=false`) — a local issue: the `.agents/plans/` file whose header reads
`> Issue: #local-<n>`. The issue body is the plan; this command carries it out, then puts the
result through the interactive review gate before calling it done. To record the outcome
afterwards, run `/ship-note`.

`$ARGUMENTS` is **optional** — extra execution notes or overrides, e.g. `skip confirm`
(auto-approve Phase 1) or `skip review` (bypass Phase 3).

## Context injected by the wrapper

The wrapper injects:
- **Harness mode** — the injected `sh .agents/scripts/harness-mode.sh` output, two lines. The
  first is `Mode: github`, `Mode: local`, or `Mode: refused`.
  - `Mode: refused` — print the second line (`Reason: …`) verbatim and **stop**: resolve
    nothing, write nothing, call no tool. The reason names the fix (a rename of
    `.agents/parallel.config`, or a `USE_GITHUB` value other than `true`/`false`).
  - `Mode: github` — the second line is the **repository remote URL** (`Remote: <url>`); parse
    `owner`/`repo` from it (HTTPS or SSH; GitHub redirects renamed repos, so the slug is always
    valid). If it reads `Remote: (none)`, stop and say there is no `origin` to resolve the
    repository from.
  - `Mode: local` — `USE_GITHUB=false` (`.agents/rules/local-mode.md`). The second line is
    ignored. For the whole run: no `mcp__github__*` tool, no `gh`, and no remote git command
    (`fetch`, `pull`, `push`, `ls-remote`).
  - **State the mode** (`Mode: github` or `Mode: local`) before this command writes anything.
- **Current branch** — the injected `git rev-parse --abbrev-ref HEAD` output.

## Resolve the issue (before Phase 1)

On `Mode: refused`, you have already stopped (see the context above).

**GitHub mode.** Resolve the issue number from the current branch using the precedence in
`.agents/rules/issue-resolution.md`: (1) leading numeric segment, (2) linked PR
`Closes/Fixes/Resolves #N`, (3) title-slug fuzzy match against non-PR issues, (4) ask the user.
A Linear-style token like `sdp-375` is **not** a GitHub issue number. Fetch the issue with
`mcp__github__issue_read` (`method: "get"`) to get its `title` and `body`.

**Local mode.** Resolve the local issue by the local precedence in
`.agents/rules/issue-resolution.md`: take the branch's leading `local-<n>` segment and run
`sh .agents/scripts/local-issues.sh find local-<n>`, which prints the one plan file whose
header reads `> Issue: #local-<n>`. If the branch carries no such segment, or `find` exits
1 (none) or 2 (more than one), run `sh .agents/scripts/local-issues.sh list --open`, show
its rows, and ask which one to use — do not proceed without an answer. Read the resolved
file: its `# ` heading is the title and the whole file is the issue body.

---

## Phase 1 — Confirmation

**Goal:** the user confirms the issue description is correct before any code is written.

1. State the mode, then show the resolved issue (`#<number> — <title>`; in local mode
   `#local-<n> — <title>` and the plan file's path), how it was resolved (numeric /
   linked-PR / title-match / local-id / user-selected), and the **issue body** (the plan to
   execute). In local mode, if its `> Status:` reads `completed` or `abandoned`, say so —
   confirming then also means reopening it.
2. If the body has an `## Open Questions` section with unresolved items, surface them and ask
   the user to resolve or waive them first.
3. Ask the user to **explicitly confirm** the description is correct and ready to execute.
   - If they want changes → tell them to edit the linked `.agents/plans/` file and re-run `/execute-issue`, then **stop**.
   - If `$ARGUMENTS` contains `skip confirm` (or equivalent), treat Phase 1 as pre-authorized
     but still print the resolved issue + a one-line plan summary before proceeding.
4. Do **not** enter Phase 2 without confirmation.

## Phase 2 — Execution

**Goal:** implement the plan exactly as described in the issue body.

1. **Find the plan source.** Search `.agents/plans/*.md` for a file whose header contains
   `> Issue: #<number>` (where `<number>` is the resolved issue number). If one exists, use
   its **Step-by-Step Implementation** as the primary source of truth and work through it in
   order. If no linked plan exists, fall back to the issue body's Step-by-Step. In either
   case, create/modify/delete the files listed under **Affected Files** in the chosen source.
   In local mode the resolved local issue file **is** that plan: use it directly and do not
   search for another.
2. **Local mode only — mark the issue in progress.** Before the first implementation edit,
   rewrite the local issue file's `> Status: **<current>**` line to
   `> Status: **in-progress**` and its `> Updated: <date>` line to today's date
   (`YYYY-MM-DD`), with the file-edit tool. Change no other line; skip both lines if the
   Status already reads `in-progress`. This is `plan-creation.md`'s Implement step applied to
   the one file that is both the issue and the plan. GitHub mode is unchanged: it never
   changes the GitHub issue's state.
3. Honor all project conventions: the architecture in `AGENTS.md`, the relevant `.agents/rules/*`
   files (read the matching rule before implementing that kind of feature), and
   the glossary family (`.agents/ubiquitous-language*.md`, reached through
   `.agents/ubiquitous-language-index.md`) for any domain code.
4. For multi-step work, track progress with the task list (`TaskCreate`/`TaskUpdate`) so the user
   can follow along.
5. Run the issue's **Acceptance Criteria** checks — use the project's acceptance commands from
   `AGENTS.md` › Commands (e.g. `pnpm lint && pnpm build` for Node, or
   `xcodebuild -scheme KeyCount build` for Swift/Xcode). Fix failures introduced by this work.
   Report results **honestly**: if something fails or is skipped, say so with the output.
   If the checks still fail after your fixes, **stop here** — report the failure with its
   output and do **not** enter Phase 3.
6. **Do not commit or push** unless the user explicitly asks (follow the global git guidance).
   This command edits the working tree only.

## Phase 3 — Review

**Goal:** the work is not done until a fresh reviewer has seen it.

1. Enter Phase 3 only if the Phase 2 acceptance checks **passed**. If they failed, stop and
   report — reviewing code the build already condemned spends context on findings nobody needs.
2. If `$ARGUMENTS` contains `skip review`, say so explicitly in the final report and go to
   step 4. This is the only way to finish an execution without a review.
3. Run the procedure in `.agents/commands/review-branch.md` with no fixed-point argument (it
   deduces one) and the default working-tree comparison form — this execution has committed
   nothing, so the three-dot form would review an empty diff (ADR-0009). Rework rounds, if any,
   happen here. In local mode that procedure reads the local issue from disk: its step 3
   copies the file to `.worktrees/<branch>.issue.md` instead of calling `gh`.
4. Once the review is approved, point the user to `/ship-note` to record what changed on the
   issue. In local mode that is a dated section appended to the local issue file.

---

## Rules

- Three phases, in order. Never start Phase 2 without Phase 1 confirmation (unless
  `skip confirm`), and never call the work done without Phase 3 (unless `skip review`).
- The linked `.agents/plans/` file (if it exists) is the source of truth for *what* to build;
  fall back to the issue body when no plan is linked. Deviate only with reason and surface
  any deviation so `/ship-note` can record it.
- Execution must obey `AGENTS.md`, the relevant `.agents/rules/*`, and the ubiquitous language.
- Report failures faithfully — never claim done when build/lint failed or a step was skipped.
- **Work is not done until an agentic review has seen it.** Only `skip review` bypasses Phase 3,
  and using it must be stated in the final report. A failing acceptance run stops before the
  review rather than skipping it.
- Working-tree only: do not commit, push, change issue state/labels, or post to the issue. In
  local mode the single write outside the implementation is Phase 2's `> Status:` /
  `> Updated:` pair, and the local issue file is never committed — the user commits plan files.
- **State the mode** before writing anything, and again in the final report; in local mode the
  report says that no GitHub call and no remote git command was made. On `Mode: refused`,
  stop before resolving the issue.
- Recording the outcome is a separate step — run `/ship-note` after execution.
