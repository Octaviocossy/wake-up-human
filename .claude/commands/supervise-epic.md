---
description: Execute an epic's child issues behind a human review gate — approve/reject each child before it integrates into the epic branch, then open one epic PR (GitHub mode) or print the push (local mode)
argument-hint: [optional epic: "#<n>" | "local-<n>" | epic plan path] [optional: "skip confirm" | "dry-run"]
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(sh .agents/scripts/run-parallel-issues.sh:*), Bash(sh .agents/scripts/harness-mode.sh:*), Bash(sh .agents/scripts/local-issues.sh:*), mcp__github__issue_read, mcp__github__list_issues, mcp__github__list_pull_requests, mcp__github__list_commits, mcp__github__create_pull_request, mcp__github__add_issue_comment, mcp__github__issue_write
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
