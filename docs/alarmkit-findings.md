# AlarmKit spike findings (M1)

Fill this in on the iPhone with the **AlarmKit spike** screen (Debug > AlarmKit spike). It answers the
M1 residual unknowns in `.agents/specs/2026-10-31-photo-alarm-mvp.md` and decides how much of the
re-alarm loop (ADR-0025) can be relied on. Read the **Intent events** list on the spike screen after
each attempt: an event line means the system ran that intent; a `followUpArmed` line means the
spike scheduled a Follow-up from it.

## Device

| Field | Value |
|-------|-------|
| Device model | |
| iOS version | |
| Build date | |
| Date tested | |

## Which dismissals run an intent

Try each dismissal once, starting from a fresh "Alarm in 1 minute" (it resets the Follow-up cap).
"Intent ran?" is taken from the Intent events list, never from memory. "Follow-up rang?" is whether
a Ring came back about a minute later.

| Dismissal | Intent ran? | Follow-up rang? | Notes |
|-----------|-------------|-----------------|-------|
| Stop button, phone locked | | | |
| Stop button, phone unlocked | | | |
| Banner swipe, phone unlocked | | | |
| Side button | | | |
| Volume button | | | |
| Other interaction with an unlocked screen (tap the banner, open the app) | | | |
| "Take photo" (also: did it open the app?) | | | |
| Ignored until it goes silent | | | |

What this means for the loop: a dismissal that runs no intent ends the loop on purpose (ADR-0025).
If the side button runs an intent, it re-arms a Follow-up and is not an escape.

- Summary:

## How long an unanswered Ring sounds

| Attempt | Phone state | Ring started | Ring stopped by itself | Duration |
|---------|-------------|--------------|------------------------|----------|
| 1 | | | | |
| 2 | | | | |

- Did anything run an intent when it stopped by itself?

## Postponing from the foreground

Switch on **Keep postponing a one-off** and stay on the spike screen.

| Question | Answer |
|----------|--------|
| Did it ring while the screen stayed visible (at least 3 minutes)? | |
| Did it ring within 60 s of locking the phone? | |
| Did it ring within 60 s of leaving the screen without locking? | |
| Did the Scheduled System alarms list show one alarm at a time? | |

- Notes (errors shown, `maximumLimitReached`, gaps between cancel and schedule):

## Brief checklist (M1 subset)

From `docs/product-brief.md`: the M1 done-when and the on-device checklist items an alarm alone can
answer. Use "Alarm in 1 minute" unless the line says otherwise.

- [ ] Rings with the phone locked
- [ ] Rings in silent mode
- [ ] Rings with the Sleep Focus on
- [ ] Rings with the app force-quit
- [ ] The weekly alarm ("Weekly alarm in 2 minutes") rings after a reboot, with the button titles shown correctly ("Stop", "Take photo", not raw keys)
- [ ] Rings after an iOS update (open the app once first so it re-schedules)
- [ ] Rings while another app is open in landscape
- [ ] Rings with Low Power Mode on
- [ ] Stop without a photo: the Follow-up returns about a minute later, up to 3 times

Anything that failed, and what was observed:

-
