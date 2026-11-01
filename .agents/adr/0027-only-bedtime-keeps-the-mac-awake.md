# Only Bedtime keeps the Mac awake; the app never wakes a sleeping Mac

A sandboxed app without administrator rights cannot wake a Mac from System sleep, and a MacBook
sleeps when its lid closes whatever assertion an app holds. So an Alarm rings only if the Mac is
already awake at its Occurrence. Bedtime is the only thing in Wake Up Human that keeps it awake:
switching Bedtime on takes a power assertion that prevents idle System sleep, and switching it off,
or a Ring replacing it, releases it. The user chose to tie the assertion to that nightly ritual
rather than to every Armed Alarm.

## Considered Options

- **Hold the assertion whenever any Alarm is Armed.** It never misses while the lid is open and
  the Mac is plugged in. But a weekday Alarm would keep the Mac from idle-sleeping all weekend, and
  "Armed" would quietly become a power policy.
- **Hold it only in the 24 hours before the next Occurrence.** If the Mac sleeps before that window
  opens, nothing can wake it to take the assertion, so the Alarm is missed without any sign.
- **Schedule a wake with `pmset schedule wake` or `IOPMSchedulePowerEvent`.** Both need root, so
  the app would need a privileged helper outside the App Sandbox. That is far more machinery than
  a personal alarm warrants.

## Consequences

Forgetting Bedtime can mean no Ring. The panel warns when an Armed Alarm is due within 12 hours
and Bedtime is off, and reports every missed Occurrence. Invariant 6 forbids "fixing" this by
holding an assertion anywhere else.

> Raised by: `/grill` on the macOS pivot, 2026-11-01.
