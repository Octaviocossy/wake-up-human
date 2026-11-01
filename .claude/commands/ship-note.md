---
description: Post a ship-note of the executed work to the current branch's issue — a GitHub comment, or a dated section of its local plan file (does not close it)
argument-hint: [optional overrides, e.g. "post-note in description"]
allowed-tools: Bash(git:*), Bash(sh .agents/scripts/harness-mode.sh:*), Bash(sh .agents/scripts/local-issues.sh:*), mcp__github__list_issues, mcp__github__issue_read, mcp__github__list_pull_requests, mcp__github__add_issue_comment, mcp__github__issue_write
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Overrides (optional): $ARGUMENTS

@.agents/commands/ship-note.md
@.agents/rules/issue-resolution.md
@.agents/rules/local-mode.md
