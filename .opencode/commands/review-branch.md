---
description: Review the current branch's work on two axes and loop rework rounds until you approve
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Options (optional): $ARGUMENTS

@.agents/commands/review-branch.md
@.agents/rules/issue-resolution.md
@.agents/rules/local-mode.md
