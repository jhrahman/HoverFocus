# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

HoverFocus is a macOS menu bar utility: focus follows the mouse, like Windows' "activate a window by hovering", across all displays, without changing the window stacking order. Swift, SwiftUI for the settings window, AppKit and the Accessibility API for window control. No third-party dependencies, no network access.

- Repo: https://github.com/jhrahman/HoverFocus (branch `main`)
- Bundle ID: `com.hoverfocus.app`
- Minimum macOS: 13 (needed for `SMAppService`). Universal binary: arm64 and x86_64.
- License: MIT

## Commands

```sh
./build.sh                 # builds build/HoverFocus.app (universal, ad-hoc signed) and build/HoverFocus.dmg
./Tools/make_icns.sh       # regenerates Resources/AppIcon.icns and AppIcon.png from Tools/make_icon.swift
```

There is no Xcode project, SwiftPM package or test target. `build.sh` calls `swiftc` once per architecture, then `lipo`.

Install a build for manual testing:

```sh
pkill -x HoverFocus; rm -rf /Applications/HoverFocus.app && cp -R build/HoverFocus.app /Applications/ && open /Applications/HoverFocus.app
```

Every rebuild changes the ad-hoc signature, so macOS drops the Accessibility grant. The user has to remove and re-add the app under Privacy & Security, Accessibility. Say so after each install.

## Architecture

All source is in `Sources/HoverFocus/`, one file per responsibility:

| File | Role |
| --- | --- |
| `main.swift`, `AppDelegate.swift` | App lifecycle, status item and menu, settings window, Dock and menu bar visibility |
| `Settings.swift` | `UserDefaults`-backed preferences (`ObservableObject`) |
| `SettingsView.swift` | SwiftUI settings window, including the "saved" confirmation toast |
| `HoverMonitor.swift` | Global mouse monitor, 30 ms throttle plus trailing evaluation, hover delay timer |
| `WindowDetector.swift` | Finds the window under the cursor from `CGWindowListCopyWindowInfo` and ignores system UI |
| `WindowFocuser.swift` | Focus logic: stale-request cancellation, key-window tracking, AX fallback |
| `SkyLight.swift` | Private focus-without-raise calls, loaded with `dlsym` |
| `SelfRaisingApps.swift` | Detects Java apps and learns other apps that raise themselves when made key |
| `AccessibilityPermission.swift` | Trust status and prompt, refreshed by a distributed notification (no polling) |
| `LoginItem.swift` | Launch at Login through `SMAppService.mainApp` |
| `MoveToApplications.swift` | Offers to copy the app into /Applications on first run |
| `Log.swift` | Opt-in debug log |

Performance rule: the app must use no CPU while the mouse is idle. Use event-driven code and one-shot timers. Do not add polling.

## Behaviours verified on macOS 26

These came out of experiments, not documentation. Check them again before building on them.

- `AXRaise` on a background app's window returns success and does nothing. Any design that tries to restore stacking order by re-raising windows will fail.
- Activating an app with `AXFrontmost` raises all of its windows. That is why the hover path avoids it.
- Focus without raise needs `_SLPSSetFrontProcessWithOptions` plus a synthetic make-key event record (`SLPSPostEventRecordTo`). Without the make-key record, AppKit apps swallow the first click.
- When switching between two windows of the same app, a resign-key record must be sent to the old window, then about 10 ms later a become-key record to the new one. Chromium needs the gap.
- Chromium and Electron apps report the focused window late through AX, so `WindowFocuser` tracks the key window itself (last focused or clicked window).
- Java apps (IntelliJ and other JetBrains IDEs) raise their window when made key, but accept the first click on an inactive window anyway. They are only activated, never made key.
- The Dock keeps an invisible window covering each display at layer 20. `WindowDetector` must skip full-display overlays, or hover focus never fires on that display.
- `AppKit` calls such as raising our own windows must happen on the main thread. Never send AX actions to HoverFocus's own windows from the focus queue.

The private calls are looked up at runtime. If a symbol is missing, `SkyLight.isAvailable` is false and the app falls back to the public AX path. Keep that fallback working.

## Testing

There is no automated suite. Test on the real machine, which has an external 1920x1080 main display and a MacBook display to its left.

1. Build and install, then run the binary directly from a shell that already has Accessibility permission (the VS Code integrated terminal does). It inherits that permission, so no re-grant is needed.
2. Drive the mouse with `CGEvent` posts and read window order with `CGWindowListCopyWindowInfo`.
3. For first-click behaviour, write a small probe app whose view logs every `mouseDown`. A click that only activates the window is not logged, so a missing line means the click was lost. Test the same app across two displays, different apps, and a Java app using the JBR `java` binary.
4. Enable the log: `defaults write com.hoverfocus.app debug -bool true`, then read `~/Library/Logs/HoverFocus.log`.
5. Crash reports are in `~/Library/Logs/DiagnosticReports/HoverFocus-*.ips`.

Do not click inside the user's real apps. Use probe windows for clicks.

## Conventions

- Swift 5 language mode (`-swift-version 5`), deployment target `macos13.0`.
- Match the surrounding code: small files, short comments that explain why, no unused abstractions.
- Keep AX and SkyLight work off the main thread, on the `hoverfocus.focus` queue in `WindowFocuser`.
- New user-facing settings go through `Settings`, get a row in `SettingsView`, and flash a confirmation message.
- Documentation and UI copy: plain, natural wording. No em dashes, no marketing filler.
- Update `README.md` when behaviour, requirements or settings change.

## Git

- Work on `main` unless told otherwise. Commit only when asked.
- `build/`, `.DS_Store` and editor folders are ignored. Never commit the DMG or the built app. Publish the DMG as a GitHub Release asset named exactly `HoverFocus.dmg`, because the README download link depends on that name.
- Do not commit personal data: home-folder paths, email addresses, tokens or certificates. Scan before committing.

## Safety guard: deleting and changing things

Never delete, move to Trash, or overwrite anything on this Mac outside this project, except:

- `/Applications/HoverFocus.app` (replaced when installing a new build)
- `~/Library/Logs/HoverFocus.log` (truncated while debugging)
- this session's scratchpad directory

This covers `rm`, `trashItem`, `mv` over existing files, `defaults delete` or `defaults write` for other apps, and quitting or closing the user's apps or windows. Do not change the user's Dock layout, login items or system settings without asking. When testing with synthetic mouse events, only move the cursor, and click only inside probe windows. Never type keystrokes into other apps.
