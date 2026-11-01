---
description: Decompose a large spec into an epic issue + N child issues with a dependency graph
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Spec (text or file path): $ARGUMENTS

@.agents/commands/spec-breakdown.md
@.agents/rules/parallel-orchestration.md
@.agents/rules/plan-creation.md
@.agents/rules/local-mode.md
