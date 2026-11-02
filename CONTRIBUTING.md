# Contributing to Wake Up Human

Thanks for helping. Issues and pull requests are welcome. Please write them in English; Spanish
is fine too.

## Before you start

- Search [existing issues](https://github.com/Octaviocossy/wake-up-human/issues) first.
- For anything bigger than a small fix, open an issue to agree on the change before writing code.
- Check the [Non-goals](README.md#non-goals) and the product invariants in
  [`.agents/ubiquitous-language-invariants.md`](.agents/ubiquitous-language-invariants.md): no
  snooze, no network calls, a Ring ends only when Dismissed or at its unattended cap, an
  Occurrence never rings late, and only Bedtime keeps the Mac awake. Changes that break one of
  them will not be merged.

## Development setup

You need Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -scheme WakeUpHuman -destination 'platform=macOS' build
xcodebuild -scheme WakeUpHuman -destination 'platform=macOS' test
swift format lint --strict --recursive WakeUpHuman WakeUpHumanTests
```

`WakeUpHuman.xcodeproj` is generated and gitignored: edit `project.yml`, never the project.

## Making a change

- Branch from `main` and keep the change focused.
- Add or update tests when behavior changes. Tests use Swift Testing and mirror the source layout
  (`WakeUpHuman/Alarms/X.swift` → `WakeUpHumanTests/Alarms/XTests.swift`); fakes live in
  `WakeUpHumanTests/Fakes/`. Conventions: [`.agents/rules/testing.md`](.agents/rules/testing.md).
- Keep every new side effect (sound, volume, power assertions, login item) behind
  `AppEnvironment.isRunningTests`, so a test run never touches the real Mac.
- Sound, the volume ramp, System sleep and the Ring window cannot be unit-tested: check them by
  hand on a Mac and say how in the pull request.
- Use the domain vocabulary in [`.agents/ubiquitous-language.md`](.agents/ubiquitous-language.md)
  (Alarm, Armed, Occurrence, Ring, Dismiss, Typing challenge, Bedtime, Notice) in code, comments
  and docs.
- Code, comments, commit messages and docs are in English. The app's user-facing text is Spanish.
- Format with `swift format format --in-place --recursive WakeUpHuman WakeUpHumanTests`.
- Write commit messages in [Conventional Commits](https://www.conventionalcommits.org/) style
  (`feat: …`, `fix: …`, `docs: …`).
- Preserve the native, dependency-free approach unless an issue establishes a clear reason to
  change it.

## Working with an AI agent (suggested)

This repository is set up for AI coding agents: [`AGENTS.md`](AGENTS.md) is the entry point for
OpenCode and Cursor, and [`CLAUDE.md`](CLAUDE.md) for Claude Code. It carries the project's rules,
glossary and slash commands. You are welcome to use one, and to review your branch with it before
you open a pull request.

The issue commands talk to GitHub by default, which does not work from a fork (your fork has no
issues). Switch the harness to **local mode** instead. Everything then runs offline, on a plan
file, with no token:

```sh
cp .agents/harness.config.example .agents/harness.config   # gitignored, per machine
# then set USE_GITHUB=false in .agents/harness.config
```

Then, in your agent:

1. `/create-issue <what you want to change>` writes a local issue: a plan file under
   `.agents/plans/` whose header reads `> Issue: #local-<n>`.
2. `git checkout -b local-<n>-<slug>`, using the branch name the command prints.
3. `/execute-issue` implements the plan and runs the project's checks.
4. `/review-branch` reviews your branch on two axes, against the project's standards and against
   the plan, and loops until you approve. The reviewer runs under `REVIEW_AGENT_EXEC_CMD` (empty
   means the same command as `AGENT_EXEC_CMD`, `claude -p --dangerously-skip-permissions` by
   default); see `.agents/harness.config.example`.

Do not commit the local plan file (`.agents/plans/*-local-*.md`). In the pull request, describe
the change and link the issue it addresses in this repository. The full local-mode contract is in
[`.agents/rules/local-mode.md`](.agents/rules/local-mode.md).

## Opening a pull request

1. Push your branch to your fork and open a pull request against `main`.
2. Fill in the template: what changed and why, what a user will notice, and how you verified it.
3. CI builds and tests the app on macOS for every pull request.

## Reporting security issues

Do not open a public issue. Follow [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
