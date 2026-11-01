# XcodeGen generates the Xcode project; no `.xcodeproj` in version control

The macOS app's Xcode project is declared in a versioned `project.yml` and generated with
`xcodegen`; the `.xcodeproj` is gitignored. This repo runs epic children concurrently in separate
worktrees, and a checked-in `project.pbxproj` is the shared-file merge hazard that
`.agents/rules/parallel-orchestration.md` › Decomposition Heuristics warns about. The choice also
matches Caffeinassy, the sibling menu-bar app whose layout this one reuses.

## Considered Options

- **A checked-in `.xcodeproj` with synchronized folders**, as the retired iOS app had. Adding a
  source file no longer touches `project.pbxproj`, but every target, build-setting or entitlement
  change still does, and the file stays unreadable in review.
- **Swift Package Manager alone.** No `pbxproj` at all, but producing a real `.app` bundle with
  `LSUIElement` and sandbox entitlements needs a hand-rolled bundling script.

## Consequences

A fresh clone cannot be opened in Xcode directly: `xcodegen generate` is a required first step,
and the build and test commands in `AGENTS.md` must run it first.

> Raised by: `/grill` on the macOS pivot, 2026-11-01.
