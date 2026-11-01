# Command: comment-issue

Add a comment to the issue that corresponds to the **current branch** — to its GitHub thread,
or, in local mode (`USE_GITHUB=false`), as a dated `## Comment — YYYY-MM-DD` section appended
to the local issue file (the `.agents/plans/` file whose header reads `> Issue: #local-<n>`).
The comment text comes from `$ARGUMENTS`.

This command only **adds a comment**. It never edits the issue body, title, state, or labels —
in local mode it never edits an existing line of the file.

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

## Instructions

1. **Read the comment text** from `$ARGUMENTS`. If empty, ask the user what to comment and stop
   (do not invent a comment).
2. **Parse `owner`/`repo`** from the injected `Remote:` line — GitHub mode only.
3. **Resolve the issue number from the current branch.**
   **GitHub mode:** use the precedence in
   `.agents/rules/issue-resolution.md`: (1) leading numeric segment, (2) linked PR
   `Closes/Fixes/Resolves #N`, (3) title-slug fuzzy match against non-PR issues, (4) ask the
   user. A Linear-style token like `sdp-375` is **not** a GitHub issue number.
   **Local mode:** the local precedence in `.agents/rules/issue-resolution.md` — leading
   `local-<n>` segment → `sh .agents/scripts/local-issues.sh find local-<n>`; no segment,
   exit 1 or exit 2 → `sh .agents/scripts/local-issues.sh list --open` and ask. The title is
   the file's `# ` heading.
4. **Compose the comment body** from `$ARGUMENTS`:
   - Post the user's text **faithfully** — preserve meaning and wording.
   - Apply only **light Markdown cleanup** (e.g. wrap code in backticks, fix list formatting).
   - Do **not** add content, headers, sign-offs, or a footer the user didn't ask for.
5. **Preview and confirm** — state the mode, show the resolved issue (`#<number> — <title>`;
   in local mode `#local-<n> — <title>` and the plan file's path) and the rendered comment —
   in local mode, as the exact section that will be appended — then wait for confirmation. A
   comment is public/outward-facing on GitHub, and a permanent part of the record in local
   mode. Skip confirmation only if `$ARGUMENTS` says so (e.g. `no confirm`).
6. **Post the comment.**
   - **GitHub mode:** `mcp__github__add_issue_comment` (`owner`, `repo`, `issue_number`, `body`).
   - **Local mode:** append to the **end** of the local issue file, after one empty line:

     ```
     ## Comment — <YYYY-MM-DD>

     <the comment body>
     ```

     `<YYYY-MM-DD>` is today's date. Append — never rewrite the file: use a shell append with a
     quoted heredoc delimiter (`cat >> "<path>" <<'EOF'`) so nothing in the text is expanded.
     Leave the header (`> Status:`, `> Updated:`) and every existing section untouched, and do
     not commit the file.
7. **Report** — GitHub mode: the issue URL (and comment URL if available). Local mode: the plan
   file's path and the heading just appended.

## Rules

- Resolve the issue from the branch using the precedence above; **confirm before posting** — in both modes.
- Comment-only — never touch the issue body, title, state, or labels. In local mode the append is the only write.
- **State the mode** before posting; on `Mode: refused`, stop. In local mode there is no GitHub call and no remote git command.
- Stay faithful to the user's text; do not editorialize or pad it.
- If the branch resolves to no issue and the user can't name one, stop — never create an issue.
