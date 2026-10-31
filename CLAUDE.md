# HoverFocus

Menu bar utility for macOS: focus follows the mouse (like Windows' "activate a window by hovering"), across all displays, without changing window stacking order.

- Sources: `Sources/HoverFocus/` (one file per responsibility). Icon generator: `Tools/make_icon.swift` → `./Tools/make_icns.sh`.
- Build: `./build.sh` → Universal `build/HoverFocus.app` + `build/HoverFocus.dmg`. Installed copy: `/Applications/HoverFocus.app`.
- Debug log: `defaults write com.hoverfocus.app debug -bool true`, then `~/Library/Logs/HoverFocus.log`.
- Focus-without-raise uses private SkyLight calls (`SkyLight.swift`), loaded with dlsym and falling back to the public AX path.

## Guard: deleting files

Never delete, move to Trash, or overwrite anything on this Mac outside this project, except:
- `/Applications/HoverFocus.app` (replaced when installing a new build),
- `~/Library/Logs/HoverFocus.log` (truncated for debugging),
- this session's scratchpad directory.

This includes `rm`, `trashItem`, `mv` over existing files, `defaults delete` for other apps, and closing/quitting the user's apps or windows. When testing with synthetic mouse events, only move the cursor and hover; don't click into other apps' windows unless the user agreed to that test, and never type keystrokes into them.
