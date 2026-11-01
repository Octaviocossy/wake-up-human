---
description: Execute the current branch's issue (GitHub, or a local plan file in local mode) in three phases — confirm, implement, review
argument-hint: [optional execution notes / overrides, e.g. "skip confirm", "skip review"]
allowed-tools: Bash(git:*), Bash(sh .agents/scripts/harness-mode.sh:*), Bash(sh .agents/scripts/local-issues.sh:*), mcp__github__list_issues, mcp__github__issue_read, mcp__github__list_pull_requests
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
