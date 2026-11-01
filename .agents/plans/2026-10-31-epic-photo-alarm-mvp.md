# Plan: Epic — Photo Alarm MVP

> Status: **draft**
> Created: 2026-10-31
> Issue: #1
> Integration branch: epic/1-photo-alarm-mvp

## Goal
Build Photo Alarm, a personal iOS 26 alarm clock (SwiftUI, AlarmKit, Vision) whose Wake-up session ends for good only after a photo of the registered Target object, or a completed Fallback. Design: `.agents/specs/2026-10-31-photo-alarm-mvp.md`.

## Children & Waves

| Wave | Issue | Branch | Title | Status |
|------|-------|--------|-------|--------|
| 1 | #2 | `2-scaffold-xcode-project` | chore: scaffold the PhotoAlarm Xcode project and toolchain | pending |
| 2 | #3 | `3-alarmkit-spike` | feat: AlarmKit scheduler, alarm intents and re-alarm spike | pending |
| 2 | #4 | `4-vision-object-setup` | feat: Vision matcher, object setup and calibration screen | pending |
| 3 | #5 | `5-wake-up-mission` | feat: wake-up mission with re-alarm loop and fallback | pending |
| 4 | #6 | `6-alarm-management` | feat: weekly alarm management with launch re-scheduling | pending |
| 5 | #7 | `7-daily-use-hardening` | feat: daily-use hardening with build-expiry banner | pending |

## Dependency Edges

```
3 -> 2
4 -> 2
5 -> 3
5 -> 4
6 -> 3
6 -> 4
6 -> 5
7 -> 6
```
