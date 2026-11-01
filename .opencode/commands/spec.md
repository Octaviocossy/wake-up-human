---
description: One-shot — break a spec into an epic + children, then execute them in parallel (add --supervised to route execution through /supervise-epic instead of /execute-epic)
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Spec (text or file path, optionally with --supervised): $ARGUMENTS

@.agents/commands/spec.md
@.agents/rules/parallel-orchestration.md
@.agents/rules/plan-creation.md
@.agents/rules/issue-resolution.md
@.agents/rules/local-mode.md
