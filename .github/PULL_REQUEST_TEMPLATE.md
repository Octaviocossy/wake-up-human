## What and why

<!-- The problem and how this change solves it. Link the issue it addresses: "Closes #<n>". -->

## User-visible changes

<!-- What someone using the app will notice, or "None". -->

## How it was verified

- [ ] `swift format lint --strict --recursive WakeUpHuman WakeUpHumanTests`
- [ ] `xcodegen generate && xcodebuild -scheme WakeUpHuman -destination 'platform=macOS' test`
- [ ] Tests added or updated for changed behavior
- [ ] Checked by hand on a Mac, if the change touches sound, volume, System sleep or the Ring window (describe how)

## Checklist

- [ ] This is not one of the [Non-goals](https://github.com/Octaviocossy/wake-up-human#non-goals)
- [ ] Reviewed with `/review-branch` (optional — see [CONTRIBUTING.md](https://github.com/Octaviocossy/wake-up-human/blob/main/CONTRIBUTING.md#working-with-an-ai-agent-suggested))
