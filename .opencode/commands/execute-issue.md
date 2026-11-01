---
description: Execute the current branch's issue (GitHub, or a local plan file in local mode) in three phases — confirm, implement, review
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Execution notes / overrides (optional): $ARGUMENTS

@.agents/commands/execute-issue.md
@.agents/rules/issue-resolution.md
@.agents/rules/local-mode.md
@.agents/rules/plan-creation.md
