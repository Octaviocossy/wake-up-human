## Install

1. Download the `.dmg` below.
2. Open the disk image and drag **WakeUpHuman** into **Applications**.
3. Open WakeUpHuman from `/Applications`. macOS blocks the first launch, because the app is ad-hoc
   signed and not notarized. Open **System Settings > Privacy & Security**, find the message about
   WakeUpHuman, and select **Open Anyway**, or remove the quarantine attribute in Terminal:

   ```sh
   xattr -dr com.apple.quarantine /Applications/WakeUpHuman.app
   ```

   Control-clicking the app and choosing Open no longer bypasses this warning.

Installing the app in `/Applications` is also required for reliable **Launch at Login**, which is
on by default.

## Before you rely on it

An Alarm rings only if the Mac is awake. Turn on Bedtime (the **Modo dormir** switch in the
menu-bar panel) at night, and leave the lid open and the Mac plugged in: the app never wakes a
sleeping Mac. With FileVault on, a restart overnight stops at the login screen, and that morning's
Alarm cannot ring. Details: [Before you rely on it](https://github.com/Octaviocossy/wake-up-human#before-you-rely-on-it).

Requires macOS 26 or later. Universal (Apple Silicon and Intel). The app lives in the menu bar,
with no Dock icon, and its interface is in Spanish.

---
