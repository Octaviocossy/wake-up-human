# Spec: Open-source README in the Caffeinassy style

> Status: **settled**
> Created: 2026-11-02
> Grilled: 2026-11-02 — 2 rounds, 22 decisions
> Suggested next: /create-issue
> Style reference: the README of the sibling app Caffeinassy (`Octaviocossy/caffeinassy`)

## Goal

Replace the root `README.md`, which is still the Agentic Workflow Scaffold's README, with a
README for the Wake Up Human app written in the style of Caffeinassy's, and give the now-public
repository what an open-source project needs: a license, contribution guidance, issue and PR
templates, a security policy, CI on `main`, and accurate GitHub metadata.

## Settled Decisions

| # | Decision | Chosen | Rationale |
|---|----------|--------|-----------|
| 1 | License | MIT, `LICENSE` at the root, "Copyright (c) 2026 Octavio Cossy Torquati" (the holder `project.yml` already names) | Same as Caffeinassy; permissive, commercial use allowed with the notice |
| 2 | CI trigger and the CI badge | `ci.yml` also runs on `push` to `main` (still on `pull_request`; no `epic/**` trigger). The README shows the CI badge. Badges, as in Caffeinassy: CI, latest release, macOS 26+, Swift 6 — no license badge | A pull-request-only workflow leaves a `main` badge without status; the repo is public, so standard macOS runners cost nothing |
| 3 | The scaffold's README content | Replaced, not preserved. The README ends its How It Works section with a short pointer to `AGENTS.md` and `.agents/docs/workflow.md`, as Caffeinassy does | The text lives upstream and in git history; it describes the harness, not the app |
| 4 | Visuals | Real screenshots of the running app, PNG, in `docs/images/` | Shows the app at a glance; prototype renders could differ from the real app |
| 5 | The headline caveat (an Alarm rings only if the Mac is awake) | A short `> [!IMPORTANT]` callout right under the intro, plus a **Before you rely on it** section: only Bedtime keeps the Mac awake (invariant 6), lid open and Mac on power, the app never wakes a sleeping Mac (ADR-0027), a FileVault restart overnight stops at the login screen, a locked screen means unlocking before typing | The most likely way a user gets a silent morning; Caffeinassy puts its own limitation in a callout at the top |
| 6 | The app's Spanish interface | Stated plainly in one line (Features or Requirements): the interface and the Typing challenge words are in Spanish. No promise of localization | Sets expectations without committing to maintain translations |
| 7 | Deliberate no-s | A **Non-goals** section: no snooze, no network/accounts/analytics (invariant 3), never waking a sleeping Mac (ADR-0027), no notarization or Mac App Store, no audio files. Links the invariants and ADRs | Stops pull requests that would be rejected |
| 8 | Tagline | "A menu-bar alarm for your Mac that only stops when you type." | Names the platform, the surface, and the one thing that makes the app different |
| 9 | Caffeinassy | One "See also: Caffeinassy" line near the end, linked | Credits the sibling app without distracting from the product |
| 10 | Companion work in scope | Harmonize `.github/RELEASE_NOTES_HEADER.md`; set the GitHub description and topics; a separate `CONTRIBUTING.md`; issue and PR templates | Open-source readiness beyond the README itself |
| 11 | Screenshots | Three: the panel (an Alarm Armed, Bedtime on), the Ring window cropped to the Typing challenge mid-way, and the status-icon states. The user captures them by hand before the merge; the PR waits for them | A Ring forces the system volume to maximum, so capturing one is a manual job |
| 12 | Repository visibility | Already public (verified 2026-11-02); no step needed. Git history was scanned before: no tokens or keys, and only `.env.mcp.example` is tracked | — |
| 13 | Recording the CI change | Decision 30 of `.agents/specs/2026-11-01-macos-typing-alarm.md` gets a one-line "superseded by" note pointing at this spec; `AGENTS.md` (Verification Quirks) and the `ci.yml` comment cite this spec and drop the "the repository is private" rationale | Keeps the old decision traceable; that spec already records amendments in place |
| 14 | The agentic harness in `CONTRIBUTING.md` | Suggests using an agent (Claude Code or OpenCode) that starts from `AGENTS.md`, and running `/review-branch` before opening a pull request | The harness is part of how the project is built; contributors can use it too |
| 15 | Harness mode for contributors | Local mode: copy `.agents/harness.config.example` to `.agents/harness.config` with `USE_GITHUB=false`; `/planning` or `/create-issue` writes a local plan, `/execute-issue` and `/review-branch` run offline. The local plan stays out of the PR; the PR links the upstream issue | In a fork, `origin` has no issues, so GitHub mode's Spec axis cannot find one; local mode needs no token |
| 16 | Language of issues and PRs | English by default; Spanish welcome | Reaches the widest audience without turning away Spanish speakers |
| 17 | Issue and PR templates | YAML issue forms in `.github/ISSUE_TEMPLATE/`: a bug form (macOS version, Mac model, app version, Bedtime on?, lid open and on power?, steps, expected vs actual) labelled `type:fix`, and a feature form that points at the Non-goals, labelled `type:feat`; `config.yml` with `blank_issues_enabled: false`; a `.github/PULL_REQUEST_TEMPLATE.md` | Most "it did not ring" reports hinge on Bedtime, power and lid; issues created by `/create-issue` through the API bypass the forms, so the harness is unaffected |
| 18 | Community files | `SECURITY.md` only: report vulnerabilities through GitHub's private vulnerability reporting, which gets enabled on the repository | Completes the security half of the community profile cheaply |
| 19 | GitHub metadata | Description = the tagline. Topics: `macos`, `menu-bar-app`, `alarm-clock`, `swift`, `swiftui`, `appkit`, `xcodegen`. Applied with `gh repo edit` after the user's go-ahead | The description is empty and there are no topics today |
| 20 | Leftover iOS labels | Delete `area:mission` and `area:vision`; rewrite the `area:alarms` description (it names AlarmKit). Keep GitHub's default labels | They describe the retired Photo Alarm and are now public |
| 21 | Release notes header | Harmonize its wording with the README's Install and Before you rely on it sections; it stays self-contained, since it is read on the release page. "Drag **WakeUpHuman**" is correct — it is the name Finder shows for `WakeUpHuman.app` — and the README uses it too. The published v1.0.1 release body is not edited | One story for installing, in both places |
| 22 | README structure and terminology | Centered icon (`WakeUpHuman/Assets.xcassets/AppIcon.appiconset/icon_256x256.png`), title, tagline, badges → intro → IMPORTANT callout → screenshots → Features → Requirements → Install → Usage → Before you rely on it → Build From Source → How It Works → Non-goals → Contributing (short, links `CONTRIBUTING.md`) → Releasing → License → See also. Glossary terms are capitalized as in Caffeinassy (Alarm, Armed, Ring, Dismiss, Typing challenge, Bedtime, Notice) and "System sleep" is never shortened to "sleep". Install links spec decision 28 for the unsigned, un-notarized build | Mirrors Caffeinassy, with the two sections this app needs; canonical terms per `domain-glossary.md` |

## Explicitly Out of Scope

- Localizing the app or inviting translations (#6).
- `CODE_OF_CONDUCT.md` (#18).
- Deleting GitHub's default labels (`bug`, `enhancement`, `documentation`, …) (#20).
- Editing `.agents/docs/workflow.md`: it is scaffold-owned, so its "see the root `README.md`"
  pointer is left stale (#3).
- Editing the published v1.0.1 release body (#21).
- A license badge (#2) and a CI trigger on `epic/**` pushes (#2).
- Renaming the product so Finder shows "Wake Up Human" (#21).
- Screenshots rendered from `docs/design/` or an animated GIF (#4).

## Glossary Changes

None.

## ADRs Raised

None. The CI trigger change is easy to reverse, and the README's content decisions restate
invariants and ADRs that already exist.

## Residual Unknowns

- **CI badge before the first run on `main`.** The badge shows no status until the merge of this
  work triggers the first `push` run.
- **The contributor flow in a fork.** Local mode is the documented contract
  (`.agents/rules/local-mode.md`), but `/create-issue` → `/execute-issue` → `/review-branch` has
  not been run end to end from a fork.
- **Usage facts.** What a left or right click on the status item does, and the exact panel
  labels, are read from `WakeUpHuman/UI/` at implementation time, not decided here.
- **Screenshots block the merge.** They depend on the user capturing them on the Mac (#11).
- **Private vulnerability reporting** needs repository admin rights to enable
  (`gh api -X PUT repos/Octaviocossy/wake-up-human/private-vulnerability-reporting`).
