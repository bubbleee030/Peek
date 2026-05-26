# Peek

Press **space** in Finder on a folder or an archive and see **what's inside** —
a real listing, not a big generic icon. Every other file type falls through to
macOS's native Quick Look untouched.

- Folders: immediate contents (folders first), with sizes.
- Archives: `.zip`, `.zipx`, `.tar`, `.tar.gz`, `.tgz`, `.gz` — listed **without
  extracting**, via the system `libarchive`.
- Runs as a quiet menu-bar agent (icon can be hidden).

## Requirements

- macOS 13+ (developed on macOS 26, Apple Silicon)
- Xcode 16+ and [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`)

## Build & run

```bash
# 1. Core logic tests
cd PeekCore && swift test

# 2. Generate and open the app
cd ../App && xcodegen generate && open Peek.xcodeproj
# In Xcode: select your Team under Signing & Capabilities (one-time), then ⌘R.
```

Or build from the command line:

```bash
cd App && xcodegen generate
xcodebuild -project Peek.xcodeproj -scheme Peek -configuration Debug -destination 'platform=macOS' build
```

## First run — permissions

Peek needs two permissions; the menu-bar **eye** icon helps you grant them:

1. **Accessibility** — to detect the spacebar. Grant it in
   System Settings → Privacy & Security → Accessibility (use the menu's
   "Grant Accessibility…" item, then re-open the menu). Relaunch Peek if the
   spacebar isn't intercepted right after granting.
2. **Automation (Finder)** — to read which item is selected. macOS prompts the
   first time you press space in Finder; click **OK**.

## Menu bar

- **Launch at Login** — toggle on to start Peek automatically.
- **Hide Menu-Bar Icon** — runs fully invisible. To bring the icon back:
  ```bash
  defaults write com.bubbleee030.peek showMenuBarIcon -bool YES
  ```
  then relaunch Peek.
- **Quit Peek**.

## How it works

- `PeekCore` (Swift package): `FolderSource`, `ArchiveSource` (libarchive shim),
  `SourceFactory`. Pure and unit-tested with `swift test`.
- `App/Peek`: a `CGEventTap` consumes space **only** when Finder is frontmost and
  the single selected item is a folder/archive; otherwise the keypress passes
  through. `FinderContext` reads the selection via Apple Events; `FocusGuard`
  avoids hijacking space while renaming. The panel is SwiftUI in an `NSPanel`.

## Design docs

- Spec: `docs/superpowers/specs/2026-05-26-peek-folder-preview-design.md`
- Plan: `docs/superpowers/plans/2026-05-26-peek-folder-preview.md`
