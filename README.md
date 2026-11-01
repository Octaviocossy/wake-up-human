# Agentic Workflow Scaffold

A project-agnostic, cross-agent (Claude Code + OpenCode) governance scaffold: plan
persistence, a domain glossary, testing conventions, GitHub issue workflows, and parallel
multi-agent orchestration — all defined once in `AGENTS.md` and `.agents/`, and consumed
identically by both agents.

Zero-dependency toolchain: POSIX `sh` + Markdown only. No `package.json`, no lockfile, no
runtime to install before you can use the scaffold itself. Because the runner,
`install-scaffold.sh` and `verify-scaffold.sh` are POSIX `sh`, Windows needs Git Bash or WSL.

## What you get

- **One set of rules, two agents.** `AGENTS.md` is the canonical entry point; `CLAUDE.md`
  inlines the same rule files via `@path` includes so Claude Code and OpenCode never drift.
- **Design interrogation** (`.agents/rules/design-interrogation.md`) — `/grill` settles a design
  by questioning before any artifact is written, then hands a spec to the right next command.
- **Plan persistence** (`.agents/rules/plan-creation.md`) — every non-trivial task gets a
  markdown plan in `.agents/plans/` before implementation starts.
- **A domain glossary family** (`.agents/ubiquitous-language*.md`) — canonical terminology,
  checked before touching domain code: the project's own vocabulary, the scaffold's own, the
  project's invariants, the scaffold's invariants, a generated index, and the changelog
  (ADR-0016, ADR-0017, ADR-0021).
- **A project-agnostic testing rule** (`.agents/rules/testing.md`) — scope and principles
  that hold regardless of stack; fill in the runner-specific placeholders once you adopt one.
- **GitHub issue workflows** — create, execute, and record issues from either agent via a
  shared GitHub MCP server.
- **Local mode** — set `USE_GITHUB=false` in `.agents/harness.config` and the same issue and
  epic workflow runs on plan files and local branches: no GitHub call, no remote read or write
  (ADR-0023).
- **Parallel multi-agent orchestration behind a review gate** — decompose a spec into an epic +
  child issues and execute the children concurrently, each in its own git worktree; every child
  passes an agentic review (and, on the supervised path, a human decision) before it can
  integrate into the epic branch.
- **Model-invoked skills** (`.agents/skills/`) — procedures the agent reaches for on its own when
  the situation matches, rather than waiting to be asked. One canonical body, symlinked into
  `.claude/skills/`, so both agents read the same file.
- **Architecture decision records** (`.agents/adr/`) — the durable store for decisions that
  outlive the task that produced them; fifteen ship with the scaffold.
- **A zero-dep acceptance gate** (`.agents/scripts/verify-scaffold.sh`) — checks the
  scaffold's own structural integrity (command triads, wrapper frontmatter, shell script
  syntax, manifest consistency, stack neutrality) with nothing beyond `sh`, `find`, and `git`.

## Install

Pick whichever fits your workflow — all three land the same files.

### 1. GitHub template repository

Click **Use this template** on the repo, or:

```sh
gh repo create my-project --template <owner>/<this-repo>
```

### 2. `degit` (one-shot copy, no git history)

```sh
npx degit <owner>/<this-repo> my-project
cd my-project
```

### 3. `/install-scaffold` (copy into an *existing* project)

Manifest-driven sync — safe to run repeatedly, and a re-run is how an upstream
correction reaches an already-installed project. It creates what the target lacks, updates
the scaffold-owned files the target never edited, leaves project-owned files alone, and
writes conflict markers — beside the path, as `<path>.scaffold-conflict`, where the path
cannot hold them — and exits non-zero where both sides moved. Requires a local
clone/checkout of this scaffold repo as the source.

From inside a clone of this scaffold repo, either invoke the slash command:

```
/install-scaffold [target-dir]
```

or run the script it wraps directly:

```sh
sh .agents/scripts/install-scaffold.sh [target-dir]   # defaults to the current directory
```

The script resolves every entry in `.agents/scaffold.manifest` (a plain list of files and
recursive directories, annotated with `# @owner scaffold` / `# @owner project` directives —
see that file for the current set) and syncs each one into `target-dir`, printing
`✓ created`, `↻ updated`, `= unchanged`, `↺ resolved`, `⊘ skipped` or `⚠ conflict` (markers in
the file, or a `<path>.scaffold-conflict` sidecar beside a symlink or a directory) per entry
and a final summary. It records what the two sides last agreed on in
`<target-dir>/.agents/scaffold.baseline` — commit that file, it is what lets the next sync
tell your edits from the scaffold's, and a resolved conflict from a fresh one. A conflicted
run exits non-zero and names each conflicted path; the `resolving-scaffold-sync` skill
resolves them, after which the file reports `resolved` once and `unchanged` from then on.

To invoke `/install-scaffold` from *any* project without `cd`-ing into this repo first, copy
`.agents/commands/install-scaffold.md` (and its two wrappers) into your agent's global commands
directory, and keep a local clone of this scaffold around as the source the script resolves
itself against — always run it from inside that clone, passing the real project directory
as the target.

## After installing

1. Fill in the placeholders in `AGENTS.md`: `## Workspace`, `## Commands`, `## Testing`,
   `## Verification Quirks`, `## Code Structure`.
2. Customize `.agents/ubiquitous-language.md` — the **project's own** domain vocabulary (the
   `Last updated` date and the canonical domain code path) — the canonical domain paths in
   `.agents/rules/domain-glossary.md`, and the runner and placement convention in
   `.agents/rules/testing.md`. Record your product's invariants in
   `.agents/ubiquitous-language-invariants.md`, which ships empty. Leave
   `.agents/ubiquitous-language-scaffold.md` and
   `.agents/ubiquitous-language-invariants-scaffold.md` alone: both are owned by the scaffold, and
   `.agents/ubiquitous-language-index.md` is generated.
3. Run the acceptance gate to confirm the scaffold landed intact:

   ```sh
   sh .agents/scripts/verify-scaffold.sh
   ```

4. Restart your agent, so `.claude/skills/` is discovered — a skills directory that did not
   exist at startup is not watched (`.agents/rules/skill-creation.md`).
5. Note that ADRs `0001`–`0015` ship with the scaffold: they record decisions your project
   inherits, so your project's own first ADR starts at `0016`.
6. If you'll use the GitHub issue commands, set up the GitHub MCP server (see below) — or set
   `USE_GITHUB=false` in `.agents/harness.config` to run them without GitHub (see Local mode).
7. If you'll use parallel orchestration or local mode, copy `.agents/harness.config.example` →
   `.agents/harness.config`, make sure your `.gitignore` lists `.agents/harness.config`, and set
   `AGENT_EXEC_CMD` (see below). An older install's `.agents/parallel.config` must be renamed:
   `mv .agents/parallel.config .agents/harness.config`.

## Layout

```
AGENTS.md                        canonical entry point (OpenCode reads this directly)
CLAUDE.md                        @-includes the same rule files, for Claude Code
.agents/
  ubiquitous-language*.md        domain glossary family: the project's own vocabulary,
                                  the scaffold's own, the project's invariants, the
                                  scaffold's invariants, a generated index, and the
                                  changelog
  labels.md                      label taxonomy (closed type: facet + open area: facet)
  scaffold.manifest              file list consumed by install-scaffold.sh
  rules/                         plan-creation, design-interrogation, domain-glossary, adr,
                                  testing, command-creation, skill-creation,
                                  parallel-orchestration, issue-resolution, local-mode
  commands/                      canonical, agent-agnostic slash command specs
  scripts/                       install-scaffold.sh, verify-scaffold.sh, sync-labels.sh,
                                  run-parallel-issues.sh, run-github-mcp.sh
                                  harness-config.sh, harness-mode.sh, local-issues.sh
  docs/                          workflow guide (workflow.md)
  plans/                         persisted implementation plans (only .gitkeep ships)
  specs/                         settled design specs from /grill (only .gitkeep ships)
  adr/                           architecture decision records (0001–0015 ship with the scaffold)
  skills/                        canonical model-invoked skills (resolving-merge-conflicts,
                                  resolving-scaffold-sync, standards-and-spec-review)
  harness.config.example         template for the (gitignored) per-machine harness config
.claude/commands/                thin Claude Code wrappers, one per .agents/commands/*.md
.claude/skills/                  relative symlinks into .agents/skills/ (Claude Code only
                                  discovers skills here; OpenCode reads .agents/skills/)
.opencode/commands/              thin OpenCode wrappers, one per .agents/commands/*.md
.mcp.json / opencode.json        GitHub MCP server registration (both agents)
.env.mcp.example                 GITHUB_TOKEN placeholder for the gitignored .env.mcp
.gitignore                       ignores .env, .env.mcp, .worktrees/, .agents/harness.config
```

## Documentation

The full day-to-day workflow — plan → implement → verify → ship, the domain
glossary, testing conventions, the GitHub issue workflow, and parallel
orchestration — is written up as a guide:
[`.agents/docs/workflow.md`](.agents/docs/workflow.md).

## Command catalog

All commands live once as a canonical spec in `.agents/commands/<name>.md` and are invoked
identically as `/<name>` from either Claude Code or OpenCode, via thin per-agent wrappers in
`.claude/commands/` and `.opencode/commands/` (see `.agents/rules/command-creation.md`).

Every issue and epic command runs in either mode: in local mode an *issue* is a local issue — a
plan file — and nothing reaches GitHub or the remote (see [Local mode](#local-mode)).

| Command | Purpose |
|---|---|
| `/grill` | Relentless design interrogation. Asks the whole decision frontier per round, sharpens the glossary inline, raises ADRs, writes a settled spec to `.agents/specs/`, and routes you to the right next command. |
| `/planning` | Create a thorough implementation plan for a feature, migration, or refactor and persist it in `.agents/plans/`. |
| `/commit-message` | Generate a Conventional-Commits message from the current diff. |
| `/install-scaffold` | Sync this scaffold into a target project directory via the manifest-driven copier. Creates what is absent, updates the scaffold-owned files the target never edited, leaves project-owned ones alone, and conflict-marks genuine divergence with a non-zero exit (ADR-0019). Safe to re-run — that is how an upstream correction lands. |
| `/create-issue` | Create a GitHub issue with a full implementation plan from a requirement description. Labels it from the taxonomy in `.agents/labels.md` — one `type:` plus an `area:` reused from the repo's existing labels, or created on demand. |
| `/update-issue` | Correct the body (and optionally title) of the current branch's GitHub issue when the initial generation was inaccurate. Re-derives the issue's labels from the corrected body. |
| `/execute-issue` | Execute the current branch's GitHub issue in three phases (confirm, implement, review); prefers the linked `.agents/plans/` file over the issue body when one exists. Phase 3 runs the `/review-branch` procedure over the result once the acceptance checks pass — `skip review` is the only bypass. |
| `/review-branch` | Review the current branch's work on two axes — Standards and Spec — and loop rework rounds until you approve. Diffs the **working tree** against the merge base by default, so it sees uncommitted work (`committed-only` opts into the three-dot form). The reviewer is dispatched under `REVIEW_AGENT_EXEC_CMD` through `.agents/scripts/run-review-agent.sh` — a different model than the implementer whenever the config says so. Presents both axes side by side under a gate line that counts hard violations and judgement calls; never merges them into one verdict. Persists its report to `.worktrees/<branch>.review.md`, appending a round per pass. User-invocable only. |
| `/comment-issue` | Add a comment to the thread of the current branch's GitHub issue, without touching its body, title, state, or labels. |
| `/ship-note` | Post a ship-note (what actually happened) to the current branch's issue as a comment. Does not close the issue. |
| `/spec-breakdown` | Decompose a large spec into an epic issue + N child issues with a dependency graph, persisted in an epic plan file. Labels the epic `type:epic`; each child is labelled from its own content, never by inheritance. |
| `/execute-epic` | Execute an epic's child issues wave-by-wave in parallel git worktrees. Each child is committed (and, in GitHub mode, pushed), passed through an agentic review, reworked automatically on a hard violation, then integrated into the epic branch — nobody is asked anything. Opens one `epic → main` PR at completion, or in local mode prints the push and a suggested `gh pr create`. Takes the epic as an optional argument. |
| `/supervise-epic` | The same staged pipeline as `/execute-epic`, with a human approve/reject decision per child at the review gate before it can integrate. User-invocable only — there is no headless equivalent. |
| `/spec` | One-shot: chains `/spec-breakdown` then, by default, `/execute-epic` — decompose, pause for review, then auto-advance every wave. Pass `--supervised` to route execution through `/supervise-epic` instead. |
| `/handoff` | Hand the current conversation off to a fresh detached background agent (`claude --bg`), seeded with a summary as its prompt. References artifacts by path rather than duplicating them; refuses to hand off an unfinished `/grill`; sandboxes the child from GitHub by default. `with-github` is refused in local mode. |

Full behavioral contracts for each command are in their canonical spec
(`.agents/commands/<name>.md`); cross-cutting conventions are in
`.agents/rules/command-creation.md`.

## Skill catalog

A **command** is something you start; a **skill** is something the agent reaches for on its own
when the situation matches its description. Skills keep one canonical body in
`.agents/skills/<name>/SKILL.md` — read natively by OpenCode — and a relative symlink at
`.claude/skills/<name>`, which is the only place Claude Code looks. Conventions are in
`.agents/rules/skill-creation.md`. Cursor reads the same canonical tree natively (and
`.claude/skills/` for compatibility), along with `AGENTS.md`. It is a reader only: slash commands
stay Claude Code and OpenCode.

| Skill | Fires when |
|-------|-----------|
| `resolving-merge-conflicts` | A git merge or rebase is mid-conflict. Reconstructs the intent behind each side (issue → plan → commits), resolves every hunk without inventing behavior, runs the project's checks, and finishes the merge. Locally grounded for this repo's GitHub MCP setup, `verify-scaffold.sh`, and the epic-branch single-writer rule. |
| `resolving-scaffold-sync` | A scaffold sync left conflict markers in a file or a conflict sidecar beside a path, or `/install-scaffold` exited non-zero naming conflicted paths. Establishes what each side was for — the scaffold's from the upstream file and the ADR it cites, the project's from its own history — resolves every marker without inventing behavior, preferring the scaffold where the file is one the project does not author, then re-runs the sync and `verify-scaffold.sh`. Not a git merge: nothing to `--continue`, and the target need not be a repository. |
| `standards-and-spec-review` | A branch needs reviewing on two axes at once: **Standards** — does it follow `AGENTS.md`, `.agents/rules/`, the ubiquitous language, and the ADRs (plus a Fowler smell baseline)? — and **Spec** — does it implement the issue, plan, or spec it came from? Each axis runs in its own sub-agent so neither pollutes the other's context, and the two reports are presented side by side without reranking. Deduces the fixed point from the branch (the epic integration branch for a child, else `main`) and shows it. Reads only; `/comment-issue` is how a report reaches GitHub. `/review-branch` is the interactive driver that adds the human gate and persists the report to `.worktrees/<branch>.review.md`. Complements `/code-review`, which hunts correctness bugs instead. |

## Design interrogation

`/grill` is the stage before planning. It models the work as a **design tree**, asks the whole
**frontier** — every decision whose prerequisites are settled — in one numbered round with a
recommended answer per question, then stops and waits. Facts are the agent's job (it dispatches
sub-agents rather than asking you what it could look up); the decisions are yours. The session
ends when the frontier is empty.

While it questions, it works the glossary actively: challenging terms that conflict with the
glossary family (`.agents/ubiquitous-language*.md`), sharpening fuzzy language, stress-testing
relationships with concrete scenarios, and cross-checking claims against real code — writing
each resolved term back **inline**, not at the end. Decisions that are hard to reverse, surprising without context,
*and* the result of a real trade-off are offered as an ADR in `.agents/adr/`.

The output is a settled spec in `.agents/specs/`, and a route to whichever command comes next:

```
/grill "offline-first sync for the mobile app"
  → rounds of Q&A until the frontier is empty
  → writes .agents/specs/2026-08-06-offline-first-sync.md
  → "Scope is 5 slices — run /spec-breakdown .agents/specs/2026-08-06-offline-first-sync.md"
```

| Scope | Next |
|---|---|
| Local, untracked | `/planning` |
| One GitHub issue | `/create-issue` → branch → `/execute-issue` → `/ship-note` |
| 3–8 slices | `/spec-breakdown <spec path>` → `/execute-epic` or `/supervise-epic` (or `/spec`, which chains either) |

`/spec-breakdown` already accepts a spec file path as its argument, so the handoff needs no
special support. Full protocol in `.agents/rules/design-interrogation.md`; ADR conventions in
`.agents/rules/adr.md`.

## GitHub MCP server

The issue-aware commands (`create-issue`, `update-issue`, `execute-issue`, `comment-issue`,
`ship-note`) reach GitHub through the **GitHub MCP server**, registered identically in
`.mcp.json` (Claude Code) and `opencode.json` (OpenCode) — both point at
`.agents/scripts/run-github-mcp.sh`, which reads only `GITHUB_TOKEN` (from the environment,
`.env.mcp`, `.env.local` or `.env`, first non-empty wins) and launches the official
`github-mcp-server` binary over stdio. No other variable in those files reaches the server.
Not needed in local mode — see below.

1. Install the server binary: `brew install github-mcp-server` (must be on `PATH`).
2. Create a fine-grained Personal Access Token for this one repository with Metadata: read,
   Contents: read, Issues: read and write, and Pull requests: read and write — the issue and
   epic commands write issues, comments and the epic PR, so a read-only token breaks them.
3. Copy `.env.mcp.example` → `.env.mcp` (gitignored, for the token alone) and set
   `GITHUB_TOKEN` to it — or set `GITHUB_TOKEN` in `.env` instead. The script exposes it to the
   server as `GITHUB_PERSONAL_ACCESS_TOKEN`.
4. Restart the agent so the MCP server is picked up.

## Local mode

Set `USE_GITHUB=false` in `.agents/harness.config` and the whole issue and epic workflow runs
without GitHub: no GitHub API call and no remote read or write, by any command (ADR-0023). Use
it in a repository whose tracker you do not own, or offline. Unset, empty or `true` keeps the
GitHub behavior; any other value is refused.

| | GitHub mode (default) | Local mode |
|---|---|---|
| Issue, epic, child | GitHub issue `#<n>` | local issue: a plan file in `.agents/plans/` with `> Issue: #local-<n>` |
| Branches | `<n>-<slug>`, `epic/<n>-<slug>` | `local-<n>-<slug>`, `epic/local-<n>-<slug>` |
| Ship-notes, comments, closing | issue comments and issue state | dated sections appended to the plan file; its `> Status:` line |
| Labels | from `.agents/labels.md` | none |
| Child branches | pushed to `origin` | stay local |
| End of an epic | one `epic → main` PR | the command prints `git push -u origin <epic>` and a suggested `gh pr create` |
| Needs | GitHub MCP server, `GITHUB_TOKEN` | git |

Every command says which mode it is in before it writes anything. No command commits plan
files for you. `sync-labels.sh` and `/handoff with-github` refuse to run in local mode. An epic
lives in the mode that created it — switching mid-epic is not supported. Full contract:
`.agents/rules/local-mode.md`.

## Parallel orchestration

`/spec-breakdown` and `/execute-epic` or `/supervise-epic` (or `/spec`, which chains
`/spec-breakdown` with one of the two, `--supervised` selecting `/supervise-epic`) decompose a
spec into an **epic** issue plus **child** issues and execute the children concurrently — one
git worktree and one headless agent process per child, run by
`.agents/scripts/run-parallel-issues.sh`. Each child branches off a real, long-lived **epic
integration branch** (`epic/<n>-<slug>`), never off `main` directly.

A child no longer merges the moment it's done. Every child passes through a **review gate**
first: an agentic `standards-and-spec-review` runs against the epic branch, and only then does
the runner integrate it — the only difference between the two commands is who resolves what the
review finds.

- **`/execute-epic`** (auto) — runs end to end with nobody watching. A **hard violation** (a
  breach of the glossary or an ADR) blocks integration and triggers automatic rework instead; a
  **judgement call** never blocks and lands only in the child's ship-note.
- **`/supervise-epic`** — the identical pipeline, plus a human approve/reject decision per
  child, informed by the diff, the agent log, and the same agentic report. A hard violation
  pre-selects "reject," but you can approve anyway. User-invocable only.

A rejected child is reworked automatically (up to `MAX_REWORK_ROUNDS`, default 2) with the
review's findings as feedback, then re-reviewed — a rework can break something the previous
round passed. Waves advance with no manual merge step; `main` receives the work only once,
through a final `epic → main` pull request.

Setup:

1. Copy `.agents/harness.config.example` → `.agents/harness.config` (gitignored).
2. Set `AGENT_EXEC_CMD` (default: `claude -p --dangerously-skip-permissions`; also documents
   `codex exec --full-auto` and `opencode run --agent <name>`) and, optionally,
   `REVIEW_AGENT_EXEC_CMD` for the agentic reviewer (empty inherits `AGENT_EXEC_CMD`).
3. Fill in `## Commands` › `Build:` / `Test:` in `AGENTS.md` — child agents read them for
   their own acceptance checks.

Full data model (wave computation, branch naming, dependency encoding, the runner's action
flags, the review gate, the rework loop, safety caps) is in
`.agents/rules/parallel-orchestration.md`.

## Verifying the scaffold

`.agents/scripts/verify-scaffold.sh` is the zero-dependency acceptance gate for the
scaffold's own structural integrity — no package manager or external tooling beyond `sh`,
`find`, and `git`. Nine groups of checks:

1. **Required files** — `AGENTS.md`, `CLAUDE.md`, `.gitignore`, and the glossary exist.
2. **Command triads** — every `.agents/commands/<name>.md` has both a Claude and an OpenCode
   wrapper, and its `# Command: <name>` heading matches its filename.
3. **Wrapper body parity** — the Claude and OpenCode wrappers are identical below the
   frontmatter, which is the only divergence `.agents/rules/command-creation.md` allows.
4. **Wrapper frontmatter** — every wrapper declares a `description:` field.
5. **Shell scripts** — everything under `.agents/scripts/` parses with `sh -n` and is executable.
6. **Scaffold manifest** — every `.agents/scaffold.manifest` entry resolves to a real path.
7. **Stack neutrality** — no tracked `src/`, `src-tauri/`, or `package.json` artifacts.
8. **Skills** — each `.agents/skills/<name>/` has a `SKILL.md` whose frontmatter `name` matches
   its directory, declares a `description`, and is symlinked into `.claude/skills/`.
9. **Manifest coverage** — the reverse of check 6: every ADR and `*.example` file actually
   appears in the manifest, so nothing lands referenced-but-not-shipped.

```sh
sh .agents/scripts/verify-scaffold.sh
```

Exit status is the number of failed checks (`0` = clean).

The gate is safe to run in a project that adopted the scaffold, not just in this repo. Checks 6,
7, 9 and the `README.md` half of check 1 only make sense in the scaffold's own source tree, so
they are gated on `.agents/scaffold.manifest` being present — and the manifest is deliberately
not listed in itself, so it never reaches an adopting project. There, those checks report as
skipped and the rest still run.
