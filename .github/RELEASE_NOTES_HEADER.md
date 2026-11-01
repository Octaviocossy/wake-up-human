## Install

1. Download the `.dmg` below.
2. Open it and drag **WakeUpHuman** onto **Applications**.
3. macOS refuses to open it the first time, because it is not signed with an Apple Developer ID.
   Get past it either via **System Settings › Privacy & Security › Open Anyway**, or by running:

   ```sh
   xattr -dr com.apple.quarantine /Applications/WakeUpHuman.app
   ```

   The old Control-click → Open shortcut no longer works.

Install it into `/Applications`: **launch at login** is on by default, and `SMAppService` registers
it reliably only from there.

**Before you rely on it.** An Alarm rings only if the Mac is awake at that time. Turn on Bedtime
(the "Modo dormir" switch in the menu-bar panel) at night, and leave the lid open and the Mac
plugged in. The app never wakes a sleeping Mac. With FileVault on, a restart overnight stops at the
login screen, and that morning's Alarm cannot ring.

Ad-hoc signed and not notarized on purpose: a personal app with no Apple Developer membership.

Requires macOS 26 or later. Universal (Apple Silicon and Intel). It lives in the menu bar, with no
Dock icon.

---
