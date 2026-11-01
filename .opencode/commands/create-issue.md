---
description: Create an issue with a full implementation plan from a requirement description (a GitHub issue, or a local plan file in local mode)
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Requirement: $ARGUMENTS

@.agents/commands/create-issue.md
@.agents/rules/plan-creation.md
@.agents/rules/local-mode.md
