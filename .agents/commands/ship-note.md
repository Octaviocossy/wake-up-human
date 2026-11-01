# Command: ship-note

Record what actually happened on the issue that corresponds to the **current branch**, once an
execution (`/execute-issue`) is done. By default the ship-note is posted as a **new issue
comment**; in local mode (`USE_GITHUB=false`) it is appended to the local issue file (the
`.agents/plans/` file whose header reads `> Issue: #local-<n>`) as a dated
`## Ship Note — YYYY-MM-DD` section.

This command **does not close the issue** and never changes its state, title, or labels — it
only records the outcome; in local mode it never rewrites `> Status:` or any other existing
line. It **always posts** — no confirmation step. `$ARGUMENTS` is **optional** — overrides
such as `post-note in description` (append to the body instead of a comment; GitHub mode only).

## Context injected by the wrapper

The wrapper injects:
- **Harness mode** — the injected `sh .agents/scripts/harness-mode.sh` output, two lines. The
  first is `Mode: github`, `Mode: local`, or `Mode: refused`.
  - `Mode: refused` — print the second line (`Reason: …`) verbatim and **stop**: resolve
    nothing, write nothing, call no tool. The reason names the fix (a rename of
    `.agents/parallel.config`, or a `USE_GITHUB` value other than `true`/`false`).
  - `Mode: github` — the second line is the **repository remote URL** (`Remote: <url>`); parse
    `owner`/`repo` from it (HTTPS or SSH). If it reads `Remote: (none)`, stop and say there is
    no `origin` to resolve the repository from.
  - `Mode: local` — `USE_GITHUB=false` (`.agents/rules/local-mode.md`). The second line is
    ignored. For the whole run: no `mcp__github__*` tool, no `gh`, and no remote git command
    (`fetch`, `pull`, `push`, `ls-remote`).
  - **State the mode** (`Mode: github` or `Mode: local`) before this command writes anything.
- **Current branch** — the injected `git rev-parse --abbrev-ref HEAD` output.

## Instructions

1. **Parse `owner`/`repo`** from the injected `Remote:` line — GitHub mode only.
2. **Resolve the issue number from the current branch.**
   **GitHub mode:** use the precedence in
   `.agents/rules/issue-resolution.md` (numeric segment → linked PR → title-slug → ask). Fetch
   the issue with `mcp__github__issue_read` (`method: "get"`) for its `title` and (only if appending) its current `body`.
   **Local mode:** the local precedence in `.agents/rules/issue-resolution.md` — leading
   `local-<n>` segment → `sh .agents/scripts/local-issues.sh find local-<n>`; no segment,
   exit 1 or exit 2 → `sh .agents/scripts/local-issues.sh list --open` and ask. Read the file
   for its `# ` heading (the title).
3. **Reconcile what actually changed** against reality — run `git status` and `git diff --stat`
   to list the files that were really created/modified/deleted. **Do not** copy the plan's
   Affected Files — report the real diff. In local mode, leave the local issue file itself out
   of the table — it is the record, not the work.
4. **Compose the ship-note** with this structure:

   ```
   ## Ship Note

   **Summary** — what was implemented, in 1–3 sentences.

   **Plan executed** — issue body, or path to the `.agents/plans/` file used.

   **Files changed**
   | Action | File Path | Notes |
   |--------|-----------|-------|
   | CREATE/MODIFY/DELETE | `path/from/root` | what changed |

   **Deviations from the plan** — where execution diverged from the Step-by-Step /
   Affected Files and why. If none, write "None — implemented as planned."

   **Validation** — project acceptance commands ✅/❌ (from `AGENTS.md` › Commands; e.g. `pnpm lint && pnpm build` or `xcodebuild … build`), plus any manual checks.

   **Follow-ups / Open Questions** — anything outstanding or deferred. If none, write "None."

   _Branch: `<current-branch>`. Recorded via `/ship-note`._
   ```

   In local mode the first line is `## Ship Note — <YYYY-MM-DD>` (today's date) instead of
   `## Ship Note`, and **Plan executed** names the local issue file's path. The rest is identical.

5. **Post the ship-note** — always post immediately; do **not** wait for confirmation.
   - GitHub mode — **Default:** a new issue comment via `mcp__github__add_issue_comment`
     (`owner`, `repo`, `issue_number`, `body`).
   - GitHub mode — **Override** (`post-note in description` or equivalent): append a `## Ship Note` section
     to the **bottom** of the issue body via `mcp__github__issue_write` (`method: "update"`; preserve the entire
     existing body — append only; send `body` only, never `state`/`title`/`labels`).
   - **Local mode:** append the composed note to the **end** of the local issue file, after one
     empty line, with a shell append (`cat >> "<path>" <<'EOF'`, quoted delimiter) — never a
     rewrite. The `post-note in description` override has no effect here (the file is both the
     thread and the description); say so if it was given. Do not touch `> Status:` or
     `> Updated:`, and do not commit the file.
6. **Report** to the user — GitHub mode: the issue URL, the comment URL (if a comment was posted), and a
   one-line outcome (succeeded / partially / blocked). Local mode: the mode, the plan file's path, the
   heading appended, and the same one-line outcome.

## Rules

- State the mode first; on `Mode: refused`, stop. Then resolve the issue from the branch using `.agents/rules/issue-resolution.md`, then **post immediately — no confirmation**.
- Reconcile the **Files changed** table against the real `git` diff — never just copy the plan.
- Report failures faithfully — if the project acceptance commands failed or a step was skipped, say so.
- **Never close the issue** or change its state, title, or labels. Default to a new comment; only
  append to the description when explicitly asked, and preserve the existing body verbatim.
  In local mode, never rewrite `> Status:` — the user closes a stand-alone local issue, and the
  epic pipeline closes a child.
- Never create a new issue. If the branch resolves to no issue and the user can't name one, stop.
