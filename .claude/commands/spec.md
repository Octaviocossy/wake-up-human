---
description: One-shot — break a spec into an epic + children, then execute them in parallel (add --supervised to route execution through /supervise-epic instead of /execute-epic)
argument-hint: [spec text OR path to a spec file] [--supervised]
allowed-tools: Bash(git:*), Bash(sh .agents/scripts/run-parallel-issues.sh:*), Bash(sh .agents/scripts/harness-mode.sh:*), Bash(sh .agents/scripts/local-issues.sh:*), mcp__github__list_issues, mcp__github__issue_write, mcp__github__issue_read, mcp__github__list_pull_requests, mcp__github__list_commits, mcp__github__create_pull_request, mcp__github__add_issue_comment
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
