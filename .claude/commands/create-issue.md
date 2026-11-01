---
description: Create an issue with a full implementation plan from a requirement description (a GitHub issue, or a local plan file in local mode)
argument-hint: [requirement description]
allowed-tools: Bash(git:*), Bash(gh label:*), Bash(sh .agents/scripts/harness-mode.sh:*), Bash(sh .agents/scripts/local-issues.sh:*), mcp__github__list_issues, mcp__github__issue_write
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Requirement: $ARGUMENTS

@.agents/commands/create-issue.md
@.agents/rules/plan-creation.md
@.agents/rules/local-mode.md
