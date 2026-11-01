# Plan: Epic — Wake Up Human macOS menu-bar alarm dismissed by typing

> Status: **draft**
> Created: 2026-11-01
> Issue: #9
> Integration branch: epic/9-wake-up-human-macos

## Goal
Pivot Wake Up Human from the retired iOS photo alarm to a macOS 26 menu-bar app: an Alarm is silenced only by typing six words shown on screen, and an optional Bedtime mode plays generated rain and keeps the Mac awake overnight. Design: `.agents/specs/2026-11-01-macos-typing-alarm.md`; visual reference: `docs/design/`.

## Children & Waves

| Wave | Issue | Branch | Title | Status |
|------|-------|--------|-------|--------|
| 1 | #10 | `10-macos-app-skeleton` | chore: pivot to the WakeUpHuman macOS menu-bar app skeleton | pending |
| 2 | #11 | `11-alarms-and-scheduling` | feat: Alarm model, Occurrence scheduling and panel alarm management | pending |
| 2 | #12 | `12-typing-challenge-ring-window` | feat: Typing challenge and Ring window | pending |
| 2 | #13 | `13-alarm-tone-system-volume` | feat: alarm tone and system volume control with the Sandbox spike | pending |
| 2 | #14 | `14-ci-release-app-icon` | chore: pull-request CI, DMG release pipeline and app icon | pending |
| 3 | #15 | `15-ring-lifecycle` | feat: Ring lifecycle from Occurrence to Dismiss or unattended cap | pending |
| 4 | #16 | `16-bedtime` | feat: Bedtime rain and keep-awake assertion | pending |
| 5 | #17 | `17-notices-status-icon-login` | feat: panel notices, status icon states, launch at login and footer | pending |

## Dependency Edges

```
11 -> 10
12 -> 10
13 -> 10
14 -> 10
15 -> 11
15 -> 12
15 -> 13
16 -> 11
16 -> 15
17 -> 11
17 -> 15
17 -> 16
```
