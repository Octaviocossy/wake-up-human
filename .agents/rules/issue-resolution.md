# Rule: Resolve the Issue from the Current Branch

Shared by every issue-aware slash command (`/execute-issue`, `/update-issue`,
`/comment-issue`, `/ship-note`). Each of those commands must map the **current branch** to
exactly one existing **issue** before doing its work, using the precedence of the active mode:

- **GitHub mode** — a GitHub issue (never a pull request), by the GitHub-mode precedence below.
- **Local mode** (`USE_GITHUB=false`; `.agents/rules/local-mode.md`) — a **local issue**: a plan
  file under `.agents/plans/` whose header reads `> Issue: #local-<n>`, by the local-mode
  precedence below.

A command applies exactly one of the two precedences, the one its wrapper's `Mode:` line names.
They never mix.

## Context injected by the wrapper

- **Mode** — the first line of the injected `sh .agents/scripts/harness-mode.sh` output:
  `Mode: github`, `Mode: local` or `Mode: refused`. After `Mode: refused` the second line is
  `Reason: <message>`: relay it and stop before resolving anything.
- **Repository remote URL** (GitHub mode) — parse `owner` and `repo` from the injected
  `Remote:` line (supports HTTPS and SSH). GitHub redirects renamed repos, so the slug from the
  remote is always valid for the API. `Remote: (none)` means the repository has no `origin`, so
  GitHub mode cannot resolve anything: stop and say so.
- **Current branch** — the injected `git rev-parse --abbrev-ref HEAD` output.

## Precedence order — GitHub mode

Stop at the first that yields a verified, existing **issue** (not a PR):

1. **Leading numeric segment** — strip a leading `user/` segment and any conventional-commit
   type prefix (`feat/`, `fix/`, `chore/`, `feat-`, `fix-`, `chore-`), then take the first bare
   numeric token (e.g. `15-nextjs-migration` → `15`). Verify with `mcp__github__issue_read` (`method: "get"`).
   Ignore numbers that are part of a Linear-style ID like `sdp-375` (letters-dash-number) —
   those are **not** GitHub issue numbers.
2. **Linked PR** — call `mcp__github__list_pull_requests` with `head: "<owner>:<branch>"` and
   `state: "all"`. If a PR matches the branch, read its body and parse the first
   `Closes|Fixes|Resolves #<n>` reference (case-insensitive). Verify that issue with
   `mcp__github__issue_read` (`method: "get"`).
3. **Title-slug fuzzy match** — derive a description slug from the branch by removing the
   `user/` prefix, any Linear-style `<team>-<number>-` prefix, and conventional-commit type
   tokens; replace `-`/`_` with spaces. Call `mcp__github__list_issues` (`state: "all"`,
   `per_page: 30`), **excluding entries that are pull requests** (those have a `pull_request`
   field or a `/pull/` html_url). Pick the issue whose title best matches the slug.
4. **Ask** — if nothing resolves confidently, list the open issues (number + title) and ask the
   user which one to use. Do not proceed without an answer.

## Precedence order — local mode

No `mcp__github__*` tool and no `gh` command runs here. Stop at the first step that yields
exactly one local issue:

1. **Leading `local-<n>` segment** — take the first `local-<n>` token that begins the branch
   name or one of its `/`-separated segments and is followed by `-` or the end of the name
   (`local-12-keystroke-capture` → `local-12`; `epic/local-7-checkout` → `local-7`). Run
   `sh .agents/scripts/local-issues.sh find local-<n>`:
   - exit 0 → the printed path is the local issue;
   - exit 2 → more than one plan claims the ID (their paths are on stderr). Report them and
     stop: an ID clash is fixed by hand, never guessed past;
   - exit 1 → no plan carries the ID; go to step 2.
2. **Ask** — run `sh .agents/scripts/local-issues.sh list --open` and show every open local
   issue (ID, status, title, path). Ask the user which one to use, and do not proceed without
   an answer. If the list is empty, stop: there is no open local issue to resolve to.

Local mode has no linked-PR step and no title-slug fuzzy match: local branches are created by
the harness's own commands, so they always carry the ID. Only the `> Issue:` header line
identifies a local issue — the file name is never read, and a plan without that line never
resolves.

## Epic and child branch shapes (from `/spec-breakdown`)

- **Child branches:** `<issue#>-<kebab-title>` (e.g. `12-keystroke-capture`). The leading
  numeric segment resolves these via precedence #1 above — no special handling required.
- **Epic branch:** `epic/<epic#>-<slug>` (e.g. `epic/55-checkout-redesign`) — the epic
  **integration branch** the parallel runner writes to (`parallel-orchestration.md`).
  The leading numeric segment (after the `epic/` prefix) resolves it via precedence #1
  above, same as a child branch — deterministic, not a fuzzy title match. This note is
  informational; the resolution precedence is unchanged.
- **Local branches** (local mode): `local-<n>-<slug>` for a stand-alone issue or an epic child,
  `epic/local-<n>-<slug>` for a local epic's integration branch. They resolve via local-mode
  step 1. Their `local-<n>` is a letters-dash-number token, so GitHub-mode precedence #1
  already ignores it: a local branch never resolves to GitHub issue `#<n>`.

## Rules

- A Linear-style token (`sdp-375`) is **not** a GitHub issue number — never treat its digits as
  one. Neither is a local ID (`local-12`).
- Resolve to an **issue**, never a pull request.
- In local mode, never call `mcp__github__*` or `gh`, and never resolve from a file name or a
  fuzzy title.
- When in doubt, ask — never guess an issue number for an outward-facing or destructive action.
