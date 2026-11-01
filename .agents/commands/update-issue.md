# Command: update-issue

Correct the body and labels (and optionally the title) of the issue that corresponds to the
**current branch**, when the initial generation by `/create-issue` was inaccurate. In GitHub
mode it writes to GitHub via `mcp__github__issue_write` (`method: "update"`). In local mode
(`.agents/rules/local-mode.md`) it rewrites the local issue's plan file in place, and a local
issue has no labels.

Use this for **correcting generation errors** in the issue — wrong scope, bad file paths,
missing steps, a mislabelled `type:` or `area:`. For evolving the implementation plan during execution, edit the linked
`.agents/plans/` file directly instead.

## Context injected by the wrapper

The wrapper injects:
- **Mode and remote** — the output of `sh .agents/scripts/harness-mode.sh`: `Mode: github`,
  `Mode: local` or `Mode: refused`, then `Remote: <origin URL>` or `Remote: (none)` — or, after
  `Mode: refused`, `Reason: <message>`. In GitHub mode, parse `owner`/`repo` from the `Remote:`
  line (HTTPS or SSH).
- **Current branch** — the injected `git rev-parse --abbrev-ref HEAD` output.

In GitHub mode the command also reads `.agents/labels.md` — the label taxonomy it re-derives
from in step 4. Local mode never reads it.

## Mode

Read the `Mode:` line before anything else:

- `Mode: refused` → write nothing. Relay the `Reason:` line to the user verbatim and stop.
- `Mode: github` → follow **Instructions — GitHub mode**.
- `Mode: local` → follow **Instructions — local mode**.

Then state the active mode to the user before writing anything (ADR-0023), e.g.
`Mode: github — updating an issue in <owner>/<repo>.` or
`Mode: local — rewriting a local issue under .agents/plans/; nothing leaves this machine.`

## Instructions — GitHub mode

When invoked (`$ARGUMENTS` = the corrections to apply):

1. **Read the correction instructions** from `$ARGUMENTS`. If empty, ask the user what to
   correct and stop.
2. **Parse `owner`/`repo`** from the injected `Remote:` line. If it reads `Remote: (none)`,
   stop: GitHub mode needs an `origin` remote. Tell the user to add one, or to set
   `USE_GITHUB=false` in `.agents/harness.config` for local mode.
3. **Resolve the issue number from the current branch** using the GitHub-mode precedence in
   `.agents/rules/issue-resolution.md` (numeric segment → linked PR → title-slug → ask).
   Fetch the issue with `mcp__github__issue_read` (`method: "get"`) to get its `title` and `body`.
4. **Apply the corrections surgically** to the body:
   - Edit only the sections the instructions touch; preserve everything else verbatim.
   - Keep the same section structure that `/create-issue` uses: Goal, Context, Affected
     Files, Step-by-Step Implementation, Architecture Decisions, Acceptance Criteria,
     Open Questions.
   - If the body already has a `## Ship Note` section at the bottom, **preserve it verbatim**
     and re-adjoin it at the bottom after the corrections.
   - If the instructions imply a title change, derive the corrected title (≤ 72 chars,
     Conventional Commits style); otherwise leave the title unchanged.
   - Inspect source files with Read/Bash when the corrections require accurate file paths,
     function signatures, or step details.
   - **Re-derive the labels** from the corrected body, exactly as `/create-issue` step 7 does
     (maximum 3, exactly one `type:`, reuse an existing `area:` before inventing one). This
     replaces the issue's labels rather than merging with them — a `type:` corrected here must
     not leave the old one behind.
5. **Preview and confirm** — show the resolved issue (`#<number> — <title>`), the corrected
   body (and new title if changed), and the re-derived labels, then wait for explicit
   confirmation before writing.
   Skip confirmation only if `$ARGUMENTS` says so (e.g. `no confirm`).
6. **Write the update** via `mcp__github__issue_write` (`method: "update"`) — always send `body`; send `title`
   only if it changed; send `labels` with the re-derived set. Never send `state`.
7. **Report** the issue URL and the labels now on the issue. If any label could not be applied,
   say which and why — the update still landed, since labelling is best-effort.

## Instructions — local mode

No `mcp__github__*` tool, no `gh` command and no remote git command runs in this mode
(`.agents/rules/local-mode.md` › Nothing leaves the machine).

When invoked (`$ARGUMENTS` = the corrections to apply):

1. **Read the correction instructions** from `$ARGUMENTS`. If empty, ask the user what to
   correct and stop.
2. **Resolve the local issue from the current branch** using the local-mode precedence in
   `.agents/rules/issue-resolution.md` (leading `local-<n>` segment → `local-issues.sh find` →
   list the open local issues and ask). Read the plan file it resolves to: its H1 is the title
   and its `## ` sections are the body.
3. **Apply the corrections surgically**, as GitHub-mode step 4 describes, with these
   differences:
   - **Header.** Keep every header line verbatim except two. The H1 title is rewritten only
     when the instructions imply a title change (≤ 72 chars, Conventional Commits style), and
     `> Updated:` is always set to today's date. Never change `> Issue:`, `> Status:`,
     `> Created:`, `> Epic:` or `> Integration branch:`. Change `> Depends on:` only when the
     instructions explicitly ask for it.
   - **Local records.** Preserve every dated record section (`## Ship Note — …`,
     `## Comment — …`, `## Failure — …`, `## Epic Summary — …`) verbatim and in order at the
     bottom of the file. This is the local counterpart of preserving `## Ship Note`.
   - **No labels.** Skip the label re-derivation entirely.
   - **File name.** Never rename the file, even when the title changes: resolution reads the
     header, never the file name, and a branch may already carry the old slug.
4. **Preview and confirm** — show the resolved issue (`#local-<n> — <title>`), its path, and the
   corrected body (and the new title if it changed), then wait for explicit confirmation
   before writing. Skip confirmation only if `$ARGUMENTS` says so (e.g. `no confirm`).
5. **Write the plan file in place.** Do not commit it.
6. **Report** the path and the sections that changed.

## Rules

- Resolve the issue from the branch using the active mode's precedence in `.agents/rules/issue-resolution.md`.
- Corrections only — edit surgically, do not rewrite the whole body unless entirely wrong.
- Preserve any `## Ship Note` section at the bottom of the body; in local mode, every dated record section.
- Preview + confirm before writing (default); `no confirm` skips the wait.
- Never change issue state or add comments. This command updates body, title and labels only — in local mode the body, the H1 title and `> Updated:`, never `> Status:` and never a new record section.
- If the branch resolves to no issue and the user can't name one, stop.
- State the mode before writing anything; on `Mode: refused`, write nothing and relay the reason.
- In local mode: no `mcp__github__*` tool, no `gh` command, no remote git command, no labels;
  never commit the plan file.
