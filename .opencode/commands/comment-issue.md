---
description: Add a comment to the current branch's issue (its GitHub thread, or a dated section of its local plan file in local mode)
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Comment text: $ARGUMENTS

@.agents/commands/comment-issue.md
@.agents/rules/issue-resolution.md
@.agents/rules/local-mode.md
