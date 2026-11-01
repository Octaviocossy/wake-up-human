# The re-alarm loop is armed only by alarm-button intents

AlarmKit's Stop button cannot be blocked, so Photo Alarm makes a stopped Ring come back by
scheduling a one-off **Follow-up** from the alarm-button intents and from nowhere else: the Stop
intent and the "Take photo" intent each schedule one about 60 s later, and only a completed
**Mission** cancels it. While the mission screen is in the foreground the app keeps pushing the
pending Follow-up forward, so it rings only once the user leaves the mission. Any dismissal for
which iOS runs neither intent ends the loop, and that is **deliberate**. It leaves an escape for a
morning when the user is already up or away from the phone. Without it, every alarm would end only
with a photo, the Fallback, or twenty minutes of rings.

Which dismissals qualify is decided by iOS, not by this app: the intent is not told how the Ring
was dismissed. Apple's AlarmKit FAQ says the stop intent also runs on a swipe or a power-button
press. A developer report on iOS 26.2.1 says it does not run for a banner swipe or an
unlocked-screen interaction. The M1 spike records the actual behavior on the device. Whatever ends
the loop, the **Wake-up session** still closes only on a completed Mission or when its Follow-up
window closes.

## Considered Options

- **Pre-scheduling the Follow-up chain as System alarms when the Alarm is scheduled**, cancelled
  on Mission completion. It keeps ringing through every dismissal and needs no intent to run, so
  it is the more robust loop. Rejected because it removes the deliberate escape. It also
  multiplies the System alarms per Alarm, which can hit AlarmKit's `maximumLimitReached`.
- **AlarmKit's native Repeat** (`secondaryButtonBehavior: .countdown`). Rejected: it takes the
  only secondary button, which "Take photo" needs, and a countdown presentation requires a widget
  extension.
