---
description: Execute an epic's child issues behind a human review gate — approve/reject each child before it integrates into the epic branch, then open one epic PR (GitHub mode) or print the push (local mode)
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Epic and options (optional): $ARGUMENTS

@.agents/commands/supervise-epic.md
@.agents/rules/issue-resolution.md
@.agents/rules/parallel-orchestration.md
@.agents/rules/local-mode.md
