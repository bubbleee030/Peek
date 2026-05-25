# Peek — Folder & Archive Contents on Spacebar

**Date:** 2026-05-26
**Status:** Approved design
**Repo:** https://github.com/bubbleee030/Preview
**App display name:** Peek · **Bundle id:** `com.bubbleee030.peek`

## Problem

In Finder, pressing space on a folder or an archive (`.zip`, `.tar`, …) shows a
big useless icon instead of what's inside. Peek replaces that one broken case:
press space on a folder or supported archive and see a list of its contents.
Every other file type is left alone so Apple's native Quick Look keeps working.

## Goals

- Press **space** in Finder on a **single folder** → window listing its immediate contents.
- Same for a **single supported archive**, listed **without extracting** it.
- For anything else, do nothing — let native Quick Look handle it.
- Run quietly in the background with a manageable menu-bar presence.

## Non-goals (v1)

- No drilling into subfolders / no expandable tree (flat immediate contents only).
- No editing, moving, deleting, or extracting.
- No 7z / rar (would need bundled third-party libraries).
- No App Store distribution / notarized installer. Build & run locally from Xcode.

## Platform & toolchain

macOS 26.4 (Tahoe), Xcode 26.4, Swift 6.3, Apple Silicon. SwiftUI for views,
AppKit for lifecycle / status item / event tap / panel.

## Architecture

Components, each with one purpose and a clear interface:

1. **AppDelegate (AppKit)** — lifecycle, menu-bar `NSStatusItem`, owns the tap and
   poller. Background agent: `LSUIElement = YES`, no Dock icon.
2. **KeyTap** — a `CGEventTap` on space key-down (keycode 49). On fire, consults
   `FinderContext` and decides **synchronously**:
   - selection is a single folder/supported archive → **consume** the event
     (return `nil`) and trigger the preview;
   - otherwise → **return the event unchanged** so native Quick Look runs.
   Re-enables itself if macOS disables the tap on timeout.
3. **FinderContext** — caches the current Finder selection. Polls Finder via
   Apple Events **only while Finder is frontmost** (`NSWorkspace.frontmostApplication`),
   ~200 ms cadence. Keeps the tap callback instant — no blocking Apple Event
   round-trip inside the tap (which would break native QL for pass-through types).
4. **ContentSource protocol** — `read() -> PreviewContents` where
   `PreviewContents = (items: [PreviewItem], totalSize: Int64, count: Int)` and
   `PreviewItem = { name, kind, sizeBytes, modified, isDirectory, icon }`.
   - **FolderSource** — `FileManager.contentsOfDirectory` with resource keys
     (`.fileSizeKey`, `.contentModificationDateKey`, `.isDirectoryKey`,
     `.localizedNameKey`, `.localizedTypeDescriptionKey`).
   - **ArchiveSource** — thin Swift wrapper over system **libarchive**
     (`archive_read_*`) enumerating entries (path, size, mtime, isdir) for
     **zip, tar, tar.gz / .tgz, gz**, without extraction.
5. **SourceFactory** — picks `FolderSource` vs `ArchiveSource` from the item's
   `UTType` (`.folder` / `.directory` vs archive types + extension fallback).
6. **PreviewPanel (SwiftUI hosted in an AppKit `NSPanel`)** — header (icon, name,
   `"12 items • 340 MB"`) + scrollable, read-only table: icon, name, kind, size,
   modified. **Folders sorted first**, then by localized name. Dismiss on **Esc**,
   **space again**, or **click-away** (resignKey).

## Data flow

```
select folder in Finder
  → space pressed
  → KeyTap reads FinderContext cache
  → single folder/archive? ── no ──> return event (native Quick Look)
        │ yes
  → consume event, post "show preview for URL"
  → SourceFactory → ContentSource.read() on a background queue
  → PreviewPanel renders header + list; becomes key window
  → Esc / space / click-away → close
```

## Permissions

- **Accessibility** — required for `CGEventTap`. First-run check; if missing, show
  guidance and a button opening
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- **Automation (Apple Events → Finder)** — for reading the selection; macOS
  prompts automatically on first Apple Event. `NSAppleEventsUsageDescription` set.
- Menu bar shows current status + a **Re-check** action.

## Menu bar

`NSStatusItem` menu:
- Permission status line (Accessibility ✓/✗).
- **Launch at login** toggle — `SMAppService.mainApp`.
- **Show menu-bar icon** toggle — off = fully invisible (persisted in
  `UserDefaults`, key `showMenuBarIcon`). Re-enable while hidden via documented
  `defaults write com.bubbleee030.peek showMenuBarIcon -bool YES` then relaunch.
- **Quit**.

## Error handling

- Unreadable folder (permissions) → message row in panel, no crash.
- Corrupt / unsupported archive → "Can't read this archive" + libarchive reason.
- Empty or **multiple** selection → pass through to native Quick Look (v1 acts on
  single selection only).
- Tap disabled by system timeout → detect `kCGEventTapDisabledByTimeout` and
  re-enable.
- Large folder / archive → enumerate off the main thread; panel shows a spinner
  then populates. Reasonable cap on rows rendered if pathological (configurable
  constant, e.g. 5,000) with a "+N more" footer.

## Testing

- **TDD (unit):** `FolderSource` against a temp directory tree; `ArchiveSource`
  against committed fixture archives (a small `.zip`, `.tar`, `.tar.gz`). Assert
  entry names, `isDirectory`, sizes, count, total size, and corrupt-file handling.
  Sources are pure and dependency-light by design.
- **Manual checklist:** event tap consume vs pass-through (folder, archive, image,
  text, multi-select, empty), permission first-run flow, menu-bar toggles,
  launch-at-login, dismiss gestures. (System key events can't be unit-tested
  reliably.)

## Build & distribution

- Standard `.xcodeproj`, single app target. Stable bundle id + signing so the
  Accessibility grant persists across rebuilds (no re-prompt each run).
- Link system `libarchive` (`/usr/lib/libarchive.*`) via a bridging header /
  module map.
- README documents: build, granting Accessibility, the menu-bar toggles, and the
  `defaults write` to un-hide the icon.

## Open questions

None — design approved through brainstorming.
