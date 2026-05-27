<div align="center">

# Peek

### See *inside* folders and archives — just press space.

Finder shows you a big useless icon when you Quick Look a folder or a `.zip`.
**Peek** fixes that one thing: hit **space** and get a real listing of what's
inside. Everything else still uses macOS's native Quick Look, untouched.

[![Download](https://img.shields.io/badge/Download-Peek%201.0-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/bubbleee030/Peek/releases/latest)
&nbsp;
![Platform](https://img.shields.io/badge/macOS-13%2B-000000?style=for-the-badge&logo=apple&logoColor=white)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-required-555?style=for-the-badge)

</div>

---

## What it does

| | |
|---|---|
| **Folders** | Press space → live listing of the contents: real Finder icons, sizes, and dates, folders first. |
| **Archives** | `.zip` · `.zipx` · `.tar` · `.tar.gz` · `.tgz` · `.gz` — listed **without extracting**, via the system `libarchive`. |
| **Quick Look feel** | The panel zooms out of the selected icon. Arrow keys move the Finder selection and Peek follows live. |
| **Stays out of the way** | Anything that isn't a folder/archive falls straight through to macOS's native Quick Look. |
| **Quiet** | Runs as a menu-bar agent — no Dock icon. The menu-bar icon can be hidden too. |

---

## Download & install

1. **[⬇️ Download the latest release](https://github.com/bubbleee030/Peek/releases/latest)** (`Peek-1.0.zip`).
2. Unzip it and drag **Peek.app** into your **Applications** folder.
3. Peek is a small personal app and **isn't notarized by Apple**, so the first
   launch shows a warning. Pick one:
   - **Right-click Peek.app → Open**, then click **Open** in the dialog, **or**
   - run this once in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/Peek.app
     ```
4. Launch Peek. Look for the **eye icon in your menu bar**.

> Prefer to build it yourself? See [Build from source](#-build-from-source).

### Grant two permissions (one time)

Peek needs these to work — the menu-bar menu walks you through them:

| Permission | Why | How |
|---|---|---|
| **Accessibility** | Detect the spacebar | Menu → **Grant Accessibility…** → enable **Peek** in System Settings → reopen the menu. *Relaunch Peek if space isn't caught right away.* |
| **Automation → Finder** | Read which item is selected | macOS prompts the first time you press space — click **OK**. |

---

## How to use

Select a folder or archive in Finder and tap **space**. That's it.

**While a preview is open:**

| Key | Default (Quick Look style) |
|---|---|
| `↑` `↓` | Move the Finder selection — Peek re-previews each folder/archive live. Land on a normal file and it hands off to native Quick Look. |
| `space` / `esc` | Close the preview (your Finder selection stays put). |
| click away | Close the preview. |

**Menu-bar options:**

- **Arrow Keys** — choose how arrows behave:
  - *Navigate Finder (Quick Look style)* — arrows change the Finder selection (default).
  - *Scroll the Preview* — arrows scroll the list inside the panel instead.
- **Zoom Effect When Opening** — toggle the scale-from-icon open animation.
- **Launch at Login** — start Peek automatically.
- **Hide Menu-Bar Icon** — run fully invisible. To bring the icon back:
  ```bash
  defaults write com.bubbleee030.peek showMenuBarIcon -bool YES
  ```
  then relaunch Peek.
- **Quit Peek**.

---

## Build from source

**Requirements:** macOS 13+, Xcode 16+, and [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/bubbleee030/Peek.git
cd Peek

# Run the core logic tests
cd PeekCore && swift test && cd ..

# Generate the Xcode project and open it
cd App && xcodegen generate && open Peek.xcodeproj
# In Xcode: pick your Team under Signing & Capabilities (one-time), then ⌘R.
```

Or straight from the command line:

```bash
cd App && xcodegen generate
xcodebuild -project Peek.xcodeproj -scheme Peek -configuration Release \
  -destination 'platform=macOS' build
```

---

## How it works

- **`PeekCore`** (Swift package) — the pure, unit-tested core: `FolderSource`,
  `ArchiveSource` (a thin shim over the system `libarchive`), and `SourceFactory`.
- **`App/Peek`** — a `CGEventTap` consumes **space** only when Finder is frontmost
  and the single selected item is a folder/archive; otherwise the keypress passes
  through to native Quick Look. `FinderContext` reads the selection via Apple
  Events, `FocusGuard` avoids hijacking space while you're renaming a file,
  `IconLocator` finds the selected icon's rect (via the Accessibility API) for the
  zoom animation, and the panel itself is SwiftUI hosted in an `NSPanel`.

Design notes live in [`docs/superpowers/`](docs/superpowers/) — the
[spec](docs/superpowers/specs/2026-05-26-peek-folder-preview-design.md) and the
[implementation plan](docs/superpowers/plans/2026-05-26-peek-folder-preview.md).

---

<div align="center">
<sub>Not affiliated with Apple. “Quick Look” and “Finder” are trademarks of Apple Inc.</sub>
</div>
