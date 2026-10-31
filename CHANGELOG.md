# Changelog

All notable changes to HoverFocus are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-31

First public release.

### Added
- Focus follows the mouse on every display and in every app
- Focus without raising: the hovered window gets focus but keeps its place in the window stack
- Optional "Bring hovered window to front" setting, with an in-app explanation
- Hover delay: Instant, 100, 250 (default), 500 or 1000 ms
- Launch at Login and "Start hidden at login"
- Menu bar icon and optional Dock icon
- Settings window with Accessibility status, version, and a confirmation message for every change
- Offer to move the app into the Applications folder on first launch
- Universal build for Apple silicon and Intel, packaged as a DMG
- Opt-in diagnostic log at `~/Library/Logs/HoverFocus.log`

### Fixed
- Chrome's extensions menu and download bubble no longer close when the mouse enters them. Popups, bubbles and tooltips are ignored, and focus only moves to regular windows
- Hover focus works on the display that holds the Dock's full-screen overlay, so main and extended displays behave the same
- Hovering between windows of the same app, such as two Chrome windows on different displays, lets the first click through
- Apps that move themselves to the front when focused (Java apps such as IntelliJ IDEA) no longer bury other windows. They are only activated

[0.1.0]: https://github.com/jhrahman/HoverFocus/releases/tag/v0.1.0
