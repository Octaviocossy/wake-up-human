---
description: Review the current branch's work on two axes and loop rework rounds until you approve
argument-hint: [optional: fixed point (branch/SHA) and/or "committed-only"]
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(mkdir:*), Bash(gh issue view:*), Bash(cp .agents/plans/:*), Bash(sh .agents/scripts/harness-mode.sh:*), Bash(sh .agents/scripts/local-issues.sh:*), Bash(sh .agents/scripts/build-corpus-pack.sh:*), Bash(sh .agents/scripts/run-review-agent.sh:*), mcp__github__issue_read, mcp__github__list_issues, mcp__github__list_pull_requests
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Current branch:
!`git rev-parse --abbrev-ref HEAD`

Options (optional): $ARGUMENTS

@.agents/commands/review-branch.md
@.agents/rules/issue-resolution.md
@.agents/rules/local-mode.md
