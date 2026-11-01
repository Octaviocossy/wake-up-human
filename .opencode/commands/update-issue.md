---
description: Correct the body (and optionally the title) of the current branch's issue (a GitHub issue, or a local plan file in local mode)
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Correction instructions: $ARGUMENTS

@.agents/commands/update-issue.md
@.agents/rules/issue-resolution.md
@.agents/rules/local-mode.md
