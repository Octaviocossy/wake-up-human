---
description: Post a ship-note of the executed work to the current branch's issue — a GitHub comment, or a dated section of its local plan file (does not close it)
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Overrides (optional): $ARGUMENTS

@.agents/commands/ship-note.md
@.agents/rules/issue-resolution.md
@.agents/rules/local-mode.md
