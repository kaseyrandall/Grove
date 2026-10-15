# Grove — notes for Claude

## Always share screenshots of UI changes

Whenever a change affects anything the player can see, send screenshots of
the result with your reply — before/after or each affected state (e.g. a
brand-new Grove and one with a few friends). Don't describe a UI change
without showing it.

- **With Xcode / the iOS Simulator available:** build, run, and capture real
  Simulator screenshots.
- **In a cloud/Linux session (no Swift toolchain):** build a faithful HTML
  replica of the changed screen — same colors (`Theme.swift`, zone gradients
  in `Habitat.swift`), sizes, copy and real catalog data — and capture it at
  iPhone size (393×852 @2x) with the preinstalled Playwright Chromium. Hide
  floating chrome (the tab bar) in full-page captures. Keep the mockup
  scripts in the scratchpad, not the repo.
- Always say which kind it is: label HTML mockups as mockups, not Simulator
  captures, and call out anything the mockup can't reproduce faithfully.
