# AGENTS.md

## Design Interrogation
- Before planning anything whose design is not already settled, run `/grill`. Full protocol in
  `.agents/rules/design-interrogation.md`.
- It models the work as a **design tree** and asks the whole **frontier** — every decision whose
  prerequisites are settled — in one numbered round, each question carrying a recommended
  answer, then stops and waits. Facts are the agent's job (dispatch sub-agents); decisions are
  the user's. Done when the frontier is empty.
- Terminology is sharpened **during** the session against the glossary family
  (`.agents/ubiquitous-language*.md`) — see the Active mode section of
  `.agents/rules/domain-glossary.md`.
- Output: a settled **design spec** at `.agents/specs/[yyyy-mm-dd]-[short-kebab-description].md`,
  plus any ADRs raised in `.agents/adr/` (`.agents/rules/adr.md`).
- The spec then routes to `/planning` (local), `/create-issue` (one issue), or
  `/spec-breakdown <spec path>` (3–8 slices). `/spec-breakdown` already accepts a spec file path,
  so no special handoff is needed.
- Never run a design interrogation inside a headless parallel-runner child — there is no human
  to answer.

## Plan Workflow
- When asked to plan or when entering plan mode, follow `.agents/rules/plan-creation.md`.
- Persist plans in `.agents/plans/[yyyy-mm-dd]-[short-kebab-description].md`.
- Present the draft for review before implementation.
- Keep the plan status updated through `draft`, `approved`, `in-progress`, `completed`, or `abandoned`.

## Domain
- The glossary is a **family of six files** (ADR-0016, ADR-0017, ADR-0021). `@`-imported:
  `.agents/ubiquitous-language-index.md` (generated term → area pointers, grouped by file),
  `.agents/ubiquitous-language-invariants.md` (this project's product invariants) and
  `.agents/ubiquitous-language-invariants-scaffold.md` (the harness's, `S`-identified, never edit
  it) — a breach of either is a hard violation at the review gate.
  On demand: `.agents/ubiquitous-language.md` (the project's) and
  `.agents/ubiquitous-language-scaffold.md` (the harness's, never edit it).
  `.agents/ubiquitous-language-changelog.md` is history, governs nothing.
- Enforcement: `.agents/rules/domain-glossary.md`. Follow without exception.
- Before touching domain code: look the term up in the index, read the file it points at. After,
  write the term in the file that owns it, bump "Last updated", add the changelog row, and
  regenerate the index.
- Decisions outliving the task go in an ADR under `.agents/adr/` — see `.agents/rules/adr.md`.

## Language
- The conversation follows the user's language. Every **artifact** — anything written for a
  later reader: a committed file, a commit message, a GitHub issue, PR or comment, a handoff
  summary, a review report — is written in English, whatever language the work was discussed
  in. Invariant: S20 in `.agents/ubiquitous-language-invariants-scaffold.md`; term: Artifact in
  `.agents/ubiquitous-language-scaffold.md` › Scaffold.
- Paraphrase what the user said in another language; quote it verbatim only when the exact
  wording is itself the subject. No bilingual exception. Generated files (corpus pack, glossary
  index, sync baseline, runner `.diff`) carry whatever their sources carry and are never
  translated.

## Testing
- Full conventions (what to test, file placement, harness usage) are in `.agents/rules/testing.md`. Read it before writing or reviewing tests.
- _Runner(s) not yet documented — fill in once a stack is adopted._

## Workspace
- Package manager: _not yet documented_
- Runtime: _not yet documented_
- Apps: _not yet documented_

## Commands
- Dev: _not yet documented_
- Build: _not yet documented_
- Lint: _not yet documented_
- Type check: _not yet documented_
- Test: _not yet documented_
- Format: _not yet documented_
- Check (lint+format): _not yet documented_

## Verification Quirks
- The runner, `install-scaffold.sh` and `verify-scaffold.sh` are POSIX `sh`: on Windows, run
  them from Git Bash or WSL.

## Skills
- A **skill** is a procedure the agent loads on its own when the situation matches its
  `description` — as opposed to a slash command, which the user starts. Full conventions in
  `.agents/rules/skill-creation.md`.
- Canonical body: `.agents/skills/<name>/SKILL.md`, surfaced to Claude Code by a relative
  symlink at `.claude/skills/<name>`. OpenCode reads `.agents/skills/` natively; Claude Code
  reads only `.claude/skills/` — hence the symlink. Reasoning in
  `.agents/adr/0001-skills-canonical-in-agents-skills.md`.
- Cursor is a reader only: it reads `AGENTS.md` and `.agents/skills/` natively (and
  `.claude/skills/` for compatibility), so a skill needs nothing Cursor-specific. Slash
  commands stay Claude Code and OpenCode.
- Vendored bodies carry no attribution footer; divergences from upstream live in
  `.agents/adr/0003-vendored-artifacts-carry-no-attribution.md`.
- Available: `resolving-merge-conflicts` — fires on an in-progress git merge/rebase conflict.
  Finds the intent behind each side, resolves every hunk without inventing behavior, runs the
  project's checks, and finishes the merge.
- Available: `standards-and-spec-review` — fires when a branch needs checking on two axes:
  **Standards** (does it follow `AGENTS.md`, `.agents/rules/`, the glossary, and the ADRs?) and
  **Spec** (does it implement the issue/plan/spec it came from?). Runs the axes as parallel
  sub-agents and reports them side by side without reranking. Deduces the fixed point from the
  branch (epic branch for a child, else `main`). Not a correctness-bug hunt — that is
  `/code-review`.
- Available: `resolving-scaffold-sync` — fires when a scaffold sync has left conflict markers
  in a file or a conflict sidecar beside a path, or `/install-scaffold` exited non-zero naming
  conflicted paths. Establishes what each side was for, resolves every marker without inventing
  behavior, then re-runs the sync and `verify-scaffold.sh`. Not a git merge — nothing to
  `--continue`, and the target need not be a repository.

## Slash Commands
- Cross-agent slash commands (Claude Code + OpenCode) follow `.agents/rules/command-creation.md`.
- Canonical specs live in `.agents/commands/<name>.md`; thin wrappers in `.claude/commands/` and `.opencode/commands/` reference them with identical bodies (only frontmatter differs).
- Invoke in either agent with `/<name>`.
- Available: `commit-message` — generate a Conventional-Commits message from the current diff.
- Available: `grill` — relentless design interrogation; writes a settled spec to `.agents/specs/`, sharpens the glossary inline, and raises ADRs. Run it before `/planning`, `/create-issue`, or `/spec-breakdown` when the design is not yet settled.
- Available: `planning` — create a thorough implementation plan and persist it in `.agents/plans/`.
- Available: `install-scaffold` — sync the cross-agent governance scaffold into a target project
  directory: creates what is absent, updates the scaffold-owned files the target never edited, and
  writes conflict markers — or a `<path>.scaffold-conflict` sidecar beside a path that cannot hold
  them (ADR-0020) — plus a non-zero exit where both sides diverged (ADR-0019).
- Available: `create-issue` — create an issue with a full implementation plan from a requirement description: a GitHub issue, or in local mode a local issue (a plan file in `.agents/plans/`).
- Available: `update-issue` — correct the body (and optionally the title) of the current branch's issue when the initial generation was inaccurate; in GitHub mode it re-derives the issue's labels alongside the body, in local mode it rewrites the local issue's plan file.
- Available: `execute-issue` — execute the current branch's issue (GitHub or local) in three phases (confirm, implement, review); uses the linked `.agents/plans/` file as primary plan source if one exists — in local mode that file is the issue. Phase 3 runs the procedure in `.agents/commands/review-branch.md`; only `skip review` bypasses it.
- Available: `review-branch` — run the two-axis review gate over the current branch's work, committed or not; presents Standards and Spec side by side under a gate line, then loops rework rounds until you approve. The reviewer is dispatched under `REVIEW_AGENT_EXEC_CMD` via `.agents/scripts/run-review-agent.sh`, so it can be a different model than the implementer — **one process per axis**, run concurrently and capped individually by `REVIEW_TIMEOUT` (default 900s), each handed its sources as files rather than as commands to re-run. In local mode the Spec axis reads the local issue's plan file where GitHub mode reads the issue body. The canonical interactive gate — `/execute-issue` Phase 3 runs its procedure. User-invocable only.
- Available: `comment-issue` — add a comment to the current branch's issue: on the GitHub thread, or in local mode as a dated `## Comment` section appended to the local issue.
- Available: `ship-note` — record a ship-note of the executed work on the current branch's issue — a GitHub comment, or in local mode a dated `## Ship Note` section appended to the local issue (does not close it).
- Available: `spec-breakdown` — decompose a large spec into an epic + N children with a dependency graph: GitHub issues, or in local mode local issues (an epic plan file plus one plan file per child, IDs assigned up front).
- Available: `execute-epic` — execute an epic's child issues wave-by-wave: each one is committed (and, in GitHub mode, pushed), passed through an agentic review, reworked automatically on a hard violation, then integrated into the epic branch; nobody is asked anything. Opens one epic PR at completion — in local mode it prints the `git push` and a suggested `gh pr create` instead. Takes the epic as an optional argument.
- Available: `supervise-epic` — the same staged pipeline as `execute-epic`, plus a human approve/reject decision per child at the review gate before it can integrate. User-invocable only — there is no headless equivalent. Takes the same optional epic argument.
- Available: `spec` — one-shot: break a spec into an epic + children, then execute them; `--supervised` at the call site routes execution through `/supervise-epic` instead of the `/execute-epic` default. It passes the epic it just created to the execution command.
- Available: `handoff` — hand this conversation off to a fresh background agent (`claude --bg`) seeded with a summary as its prompt; one detached continuation in this working tree, sandboxed from GitHub unless `with-github`, which local mode refuses (S22). Claude Code only — OpenCode has no background mode and prints the summary instead.

## GitHub MCP server
- The GitHub issue commands (`create-issue`, `update-issue`, `execute-issue`,
  `comment-issue`, `ship-note`) reach GitHub through the
  **GitHub MCP server**, registered in `.mcp.json` (Claude Code) and `opencode.json` (OpenCode).
- Both registrations point at `.agents/scripts/run-github-mcp.sh`, which reads only
  `GITHUB_TOKEN` (from the environment, `.env.mcp`, `.env.local` or `.env`, first non-empty
  wins) and launches the official `github-mcp-server` over stdio. No other variable in those
  files reaches the server, and none of them runs as shell code.
- Install the server binary with `brew install github-mcp-server` (it must be on PATH; the
  script also prepends the Homebrew bin dirs for GUI-launched agents). This replaces the
  deprecated npm package `@modelcontextprotocol/server-github`.
- Set `GITHUB_TOKEN` in `.env`, or in `.env.mcp` (gitignored, for the token alone), to a
  fine-grained Personal Access Token for this one repository with Metadata: read, Contents:
  read, Issues: read and write, and Pull requests: read and write. The issue and epic
  commands write issues, comments and the epic PR, so a read-only token breaks them. The
  script exposes it to the server as `GITHUB_PERSONAL_ACCESS_TOKEN`.
- Restart the agent after first configuring the token so the MCP server is picked up.
- Not needed in local mode (`USE_GITHUB=false`) — see Local Mode below.

## Local Mode
- `USE_GITHUB=false` in `.agents/harness.config` (per machine, gitignored — copy
  `.agents/harness.config.example`) switches the whole harness to **local mode**: no GitHub API
  call and no remote read or write, by any command (S22; ADR-0023). Unset, empty or `true` is
  GitHub mode — the behavior described everywhere else in this file. Any other value is refused.
- Every issue and epic command reads the mode from `.agents/scripts/harness-mode.sh` and states
  it before it writes anything; on `Mode: refused` it stops and relays the reason. A leftover
  `.agents/parallel.config` is refused until renamed:
  `mv .agents/parallel.config .agents/harness.config`.
- Issues, epics and children become **local issues**: plan files in `.agents/plans/` whose
  header carries `> Issue: #local-<n>` (`<yyyy-mm-dd>-local-<n>-<slug>.md`; an epic is
  `<yyyy-mm-dd>-epic-local-<n>-<slug>.md`). IDs come from
  `sh .agents/scripts/local-issues.sh next-ids <k>`; branches are `local-<n>-<slug>` and
  `epic/local-<n>-<slug>`. Full contract: `.agents/rules/local-mode.md`.
- What GitHub recorded, the plan file records: a ship-note, comment, failure note or epic
  summary is a dated section appended to it, closing a child sets its `> Status:` to
  `completed`, and ticking the epic sets that child's cell in its `## Children & Waves` table.
  There are no labels. No command commits a plan file — the user does.
- The epic branch leaves the machine only when the user pushes it: at completion
  `/execute-epic` and `/supervise-epic` print the `git push -u origin <epic>` and a suggested
  `gh pr create` instead of opening a PR.
- Not needed in local mode: the GitHub MCP server and `GITHUB_TOKEN`. `sync-labels.sh` and
  `/handoff with-github` refuse to run; `/handoff` without `with-github` is unchanged.
- An epic lives in the mode that created it: switching `USE_GITHUB` mid-epic, or promoting
  local issues to GitHub when the branch is pushed, is not supported.

## Issue Labels

- Issues created by `/create-issue` and `/spec-breakdown` carry labels from the taxonomy in
  `.agents/labels.md`. `/update-issue` re-derives them; `/ship-note`, `/comment-issue`,
  `/execute-issue` and `/handoff` never touch them.
- **Two facets.** `type:` is closed — the Conventional Commits prefixes, enumerated in the
  taxonomy. `area:` is open — declared but not enumerated, because its values are
  project-specific and this scaffold is stack-neutral. Maximum 3 labels, exactly one `type:`.
- **Reuse before invent.** An `area:` value is reused from the repo's existing labels whenever
  one covers the issue; a genuinely new one is created on demand with `gh label create`.
- **Labels are informational.** Nothing in either execution path, the runner, or the review gate
  reads one back — see `.agents/adr/0015-issue-labels-are-informational.md`. Applying one is
  best-effort and never blocks issue creation.
- **Provisioning:** run `sh .agents/scripts/sync-labels.sh` once per repository (and again when
  the taxonomy changes) to create the closed facet in GitHub. `/install-scaffold` does not call
  it — that copier stays local and offline. In local mode there are no labels and the script
  refuses to run (S22).

## Parallel Orchestration

Decompose a large spec into an epic + N child issues and execute them in parallel via a POSIX
shell runner. Full conventions in `.agents/rules/parallel-orchestration.md`.

**Epic/child model:** An *epic* is a GitHub issue with a child task-list + ` ```waves ` graph
block, backed by a real, long-lived **epic integration branch** `epic/<epic#>-<slug>`. Each
*child* is a full-plan issue with `> Epic: #<n>` and `> Depends on: #…` headers. Children use
branch names `<issue#>-<kebab-title>` and branch off the epic branch, not `main` directly. In
local mode the epic and its children are local issues, and the branches are
`epic/local-<n>-<slug>` and `local-<n>-<slug>` (see Local Mode).

**Setup (one-time):**
1. Copy `.agents/harness.config.example` → `.agents/harness.config` (gitignored); add
   `USE_GITHUB=false` there for local mode.
2. Set `AGENT_EXEC_CMD` (default: `claude -p --dangerously-skip-permissions`).
3. Ensure `Build:` and `Test:` in `## Commands` above are filled in — child agents read them.

**Runner:** `.agents/scripts/run-parallel-issues.sh` — one worktree + headless agent per child,
concurrent up to `PARALLEL_MAX_CONCURRENCY` (default 3). A plain run only commits each child —
and, in GitHub mode, pushes it; it never integrates. Given `--epic <branch>`, three further
action flags drive a child through the rest of the pipeline: `--review` (fans out an agentic
`standards-and-spec-review` — two single-axis reviewer processes per child via
`run-review-agent.sh`, ADR-0014 — per child), `--rework` (re-dispatches a rejected child with
feedback), and `--integrate` (the only action that merges into the epic branch). The
orchestrating agent only reads epic-branch state and, in GitHub mode, opens the final PR via
MCP — the runner is the epic branch's sole writer throughout. `GITHUB_TOKEN` is never sourced
by the runner — headless agents have no GitHub access by design. In local mode the runner
runs no remote command at all.

**The review gate:** every child passes an agentic review before it can integrate, on both
execution paths. `/execute-epic` (auto) resolves it alone — a hard violation blocks integration
and triggers automatic rework, a judgement call never blocks; nobody is asked anything.
`/supervise-epic` runs the identical pipeline plus a human approve/reject decision per child,
informed by the diff, the agent log, and the same agentic report; a hard violation pre-selects
"reject" but the human has the final say. `/spec` defaults to the auto path; pass `--supervised`
at the call site to route it through `/supervise-epic` instead. The runner pre-builds a
**corpus pack** (`.worktrees/.corpus-pack.md`) once per `--review` invocation so the
standards sources are read once rather than once per context, and the caller pre-writes
`.worktrees/.epic-issue.md` so the Spec axis sees the epic's scope headless. Full contract
(the runner's action flags, the rework loop, `REVIEW_AGENT_EXEC_CMD`, `MAX_REWORK_ROUNDS`)
in `.agents/rules/parallel-orchestration.md`.

**Wave flow:** either command creates an epic integration branch `epic/<epic#>-<slug>` and runs
each runnable wave through the full pipeline — run → review → optional rework → integrate — in
one invocation; waves advance with no manual merge step. Each integrated child issue is
**closed** (in local mode, its plan's `> Status:` becomes `completed`) and its branch
**deleted** (opt out with `KEEP_CHILD_BRANCHES=1`). At completion it opens a single
`epic → main` PR; in local mode it prints the `git push` and a suggested `gh pr create`
instead. Both commands take the epic as an optional argument — `#<n>` or `<n>` in GitHub mode,
`local-<n>` or the epic plan's path in local mode; without one, GitHub mode resolves the epic
from the current branch and local mode lists the epics that still have unintegrated children.
Re-running is idempotent (done children are detected from the epic branch).

**Safety caps:** `MAX_CHILDREN=12`, `AGENT_TIMEOUT=1800s`, `PARALLEL_MAX_CONCURRENCY=3`,
`MAX_REWORK_ROUNDS=2`, `KEEP_CHILD_BRANCHES=0`. Override in `.agents/harness.config`.

## Code Structure
<!-- TODO: document the framework, router style, key directories, and any import conventions -->
_None documented yet._
