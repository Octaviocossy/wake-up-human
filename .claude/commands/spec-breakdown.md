---
description: Decompose a large spec into an epic issue + N child issues with a dependency graph
argument-hint: [spec text pasted inline, OR a path to a spec file you attach, e.g. ./spec.md]
allowed-tools: Bash(git:*), Bash(gh label:*), Bash(sh .agents/scripts/harness-mode.sh:*), Bash(sh .agents/scripts/local-issues.sh:*), mcp__github__list_issues, mcp__github__issue_write
---

Harness mode, then the repository remote (state the mode before writing anything; stop on `Mode: refused`; in GitHub mode parse owner/repo from the `Remote:` line):
!`sh .agents/scripts/harness-mode.sh`

Spec (text or file path): $ARGUMENTS

@.agents/commands/spec-breakdown.md
@.agents/rules/parallel-orchestration.md
@.agents/rules/plan-creation.md
@.agents/rules/local-mode.md
