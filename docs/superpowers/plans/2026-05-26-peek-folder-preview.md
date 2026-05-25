# Peek — Folder & Archive Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A background macOS app ("Peek") that, when you press space in Finder on a single folder or supported archive, shows a window listing its contents instead of a generic icon — passing every other file type through to native Quick Look.

**Architecture:** A `PeekCore` Swift package holds the pure, unit-tested logic (content readers + a libarchive interop shim). An XcodeGen-generated Xcode app ("Peek") depends on `PeekCore` and adds the AppKit/SwiftUI shell: a `CGEventTap` for the spacebar, an Apple-Events poller for the Finder selection, the SwiftUI preview panel, and a menu-bar controller.

**Tech Stack:** Swift 6, SwiftPM (PeekCore), XcodeGen + Xcode (app), AppKit + SwiftUI, ApplicationServices (Accessibility / CGEventTap), ScriptingBridge-free Apple Events via `NSAppleScript`, system `libarchive` (vendored declaration shim), `SMAppService` (launch at login).

**Repo:** https://github.com/bubbleee030/Peek · **Bundle id:** `com.bubbleee030.peek` · local working copy at `/Users/bubble/Vscode/Preview`.

---

## File Structure

```
/ (repo root, working copy at /Users/bubble/Vscode/Preview)
  PeekCore/
    Package.swift
    Sources/
      CLibArchive/
        module.modulemap          # vendored libarchive module (link "archive")
        shim.h                    # minimal libarchive declarations (Apple ships no headers)
      PeekCore/
        PreviewItem.swift         # PreviewItem + PreviewContents models
        ContentSource.swift       # ContentSource protocol + ContentSourceError
        FolderSource.swift        # lists a directory's immediate children
        ArchiveSource.swift       # lists archive entries via libarchive (no extraction)
        SourceFactory.swift       # folder vs archive vs unsupported, by type/extension
    Tests/
      PeekCoreTests/
        ArchiveFixtures.swift     # builds zip/tar.gz fixtures in a temp dir at runtime
        FolderSourceTests.swift
        ArchiveSourceTests.swift
        SourceFactoryTests.swift
  App/
    project.yml                   # XcodeGen spec -> Peek.xcodeproj
    Peek/
      main.swift                  # NSApplication bootstrap (accessory policy)
      AppDelegate.swift           # wires FinderContext, KeyTap, PreviewController, MenuBar
      FinderContext.swift         # polls Finder selection via Apple Events
      FocusGuard.swift            # AX check: is a text field focused? (don't hijack rename)
      KeyTap.swift                # CGEventTap: consume space for folders/archives only
      PreviewController.swift     # owns the NSPanel, dismissal handling
      PreviewViewModel.swift      # loads contents off-main-thread, publishes state
      PreviewView.swift           # SwiftUI header + read-only list
      MenuBarController.swift     # NSStatusItem menu (perms, login, hide icon, quit)
      Info.plist
      Peek.entitlements
  docs/superpowers/...            # spec + this plan
  README.md
  .gitignore                      # already present
```

---

## Task 1: Scaffold PeekCore package

**Files:**
- Create: `PeekCore/Package.swift`
- Create: `PeekCore/Sources/PeekCore/PreviewItem.swift`
- Create: `PeekCore/Sources/PeekCore/ContentSource.swift`

- [ ] **Step 1: Create `PeekCore/Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PeekCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PeekCore", targets: ["PeekCore"]),
    ],
    targets: [
        .systemLibrary(name: "CLibArchive", path: "Sources/CLibArchive"),
        .target(name: "PeekCore", dependencies: ["CLibArchive"]),
        .testTarget(name: "PeekCoreTests", dependencies: ["PeekCore"]),
    ]
)
```

- [ ] **Step 2: Create the model file `PeekCore/Sources/PeekCore/PreviewItem.swift`**

```swift
import Foundation

/// One row in a preview listing — a child of a folder, or an entry in an archive.
public struct PreviewItem: Equatable, Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let isDirectory: Bool
    public let sizeBytes: Int64
    public let modified: Date?

    public init(name: String, isDirectory: Bool, sizeBytes: Int64, modified: Date?) {
        self.name = name
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.modified = modified
    }
}

/// The full result of reading a folder or archive.
public struct PreviewContents: Equatable, Sendable {
    public let items: [PreviewItem]
    public let totalSize: Int64
    public var count: Int { items.count }

    public init(items: [PreviewItem], totalSize: Int64) {
        self.items = items
        self.totalSize = totalSize
    }
}
```

- [ ] **Step 3: Create `PeekCore/Sources/PeekCore/ContentSource.swift`**

```swift
import Foundation

/// Anything that can produce a flat listing. Sendable so a source can be read
/// off the main thread from the app's view model.
public protocol ContentSource: Sendable {
    func read() throws -> PreviewContents
}

public enum ContentSourceError: Error, Equatable {
    case cannotRead(String)
    case unsupported(String)
}
```

- [ ] **Step 4: Create the libarchive interop directory placeholder so the package resolves**

Create `PeekCore/Sources/CLibArchive/module.modulemap`:

```
module CLibArchive {
    header "shim.h"
    link "archive"
    export *
}
```

Create `PeekCore/Sources/CLibArchive/shim.h`:

```c
#ifndef PEEK_CLIBARCHIVE_SHIM_H
#define PEEK_CLIBARCHIVE_SHIM_H

#include <stddef.h>

/* macOS links libarchive (libarchive.tbd is in the SDK) but ships no public
   headers, so we declare exactly the symbols we use. Verified exported. */

struct archive;
struct archive_entry;

struct archive *archive_read_new(void);
int archive_read_support_filter_all(struct archive *);
int archive_read_support_format_all(struct archive *);
int archive_read_open_filename(struct archive *, const char *filename, size_t block_size);
int archive_read_next_header(struct archive *, struct archive_entry **);
int archive_read_data_skip(struct archive *);
int archive_read_free(struct archive *);
const char *archive_error_string(struct archive *);

const char *archive_entry_pathname(struct archive_entry *);
long long archive_entry_size(struct archive_entry *);
long archive_entry_mtime(struct archive_entry *);
unsigned short archive_entry_filetype(struct archive_entry *);

#endif
```

- [ ] **Step 5: Create a temporary empty PeekCore source so the target compiles**

Create `PeekCore/Sources/PeekCore/SourceFactory.swift` with a placeholder that the next tasks replace:

```swift
import Foundation

public enum SourceFactory {
    public static func source(for url: URL) -> ContentSource? { nil }
}
```

- [ ] **Step 6: Verify the package builds**

Run: `cd PeekCore && swift build`
Expected: `Build complete!` (the `link "archive"` resolves; no header errors).

- [ ] **Step 7: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add PeekCore
git commit -m "feat: scaffold PeekCore package with libarchive shim"
```

---

## Task 2: FolderSource (TDD)

**Files:**
- Create: `PeekCore/Tests/PeekCoreTests/FolderSourceTests.swift`
- Create: `PeekCore/Sources/PeekCore/FolderSource.swift`

- [ ] **Step 1: Write the failing test**

Create `PeekCore/Tests/PeekCoreTests/FolderSourceTests.swift`:

```swift
import XCTest
@testable import PeekCore

final class FolderSourceTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peek-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testListsImmediateChildrenWithSizesAndFoldersFirst() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try "hello\n".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8) // 6 bytes
        try "hi\n".write(to: dir.appendingPathComponent("z.txt"), atomically: true, encoding: .utf8)    // 3 bytes
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)

        let contents = try FolderSource(url: dir).read()

        XCTAssertEqual(contents.count, 3)
        // folders first, then files alphabetically
        XCTAssertEqual(contents.items.map(\.name), ["sub", "a.txt", "z.txt"])
        XCTAssertTrue(contents.items[0].isDirectory)
        XCTAssertEqual(contents.items[1].sizeBytes, 6)
        XCTAssertEqual(contents.items[2].sizeBytes, 3)
        XCTAssertEqual(contents.totalSize, 9)
    }

    func testSkipsHiddenFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "x".write(to: dir.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)
        try "y".write(to: dir.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)

        let contents = try FolderSource(url: dir).read()
        XCTAssertEqual(contents.items.map(\.name), ["visible.txt"])
    }

    func testUnreadableFolderThrowsCannotRead() {
        let missing = URL(fileURLWithPath: "/this/does/not/exist-\(UUID().uuidString)")
        XCTAssertThrowsError(try FolderSource(url: missing).read()) { error in
            guard case ContentSourceError.cannotRead = error else {
                return XCTFail("expected cannotRead, got \(error)")
            }
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd PeekCore && swift test --filter FolderSourceTests`
Expected: FAIL — `cannot find 'FolderSource' in scope`.

- [ ] **Step 3: Write the implementation**

Create `PeekCore/Sources/PeekCore/FolderSource.swift`:

```swift
import Foundation

public struct FolderSource: ContentSource {
    public let url: URL
    public init(url: URL) { self.url = url }

    private static let keys: [URLResourceKey] = [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey,
    ]

    public func read() throws -> PreviewContents {
        let fm = FileManager.default
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Self.keys,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw ContentSourceError.cannotRead(error.localizedDescription)
        }

        var items: [PreviewItem] = []
        var total: Int64 = 0
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: Set(Self.keys))
            let isDir = values?.isDirectory ?? false
            let size = Int64(values?.fileSize ?? 0)
            let name = values?.name ?? entry.lastPathComponent
            items.append(PreviewItem(
                name: name,
                isDirectory: isDir,
                sizeBytes: size,
                modified: values?.contentModificationDate
            ))
            total += size
        }
        items.sort(by: Self.order)
        return PreviewContents(items: items, totalSize: total)
    }

    /// Folders first, then localized natural name order. Shared with ArchiveSource.
    public static func order(_ a: PreviewItem, _ b: PreviewItem) -> Bool {
        if a.isDirectory != b.isDirectory { return a.isDirectory }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd PeekCore && swift test --filter FolderSourceTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add PeekCore/Sources/PeekCore/FolderSource.swift PeekCore/Tests
git commit -m "feat: FolderSource lists directory contents, folders first"
```

---

## Task 3: Archive fixtures helper

**Files:**
- Create: `PeekCore/Tests/PeekCoreTests/ArchiveFixtures.swift`

Builds deterministic `.zip` and `.tar.gz` fixtures at runtime using the system `zip`/`tar` binaries, so no binaries are committed and entry names are known.

- [ ] **Step 1: Create the helper**

```swift
import Foundation
import XCTest

/// Builds archives in a temp dir from a known tree:
///   a.txt        -> "hello\n"  (6 bytes)
///   sub/b.txt    -> "hi\n"     (3 bytes)
enum ArchiveFixtures {
    struct Built {
        let root: URL
        let zip: URL
        let targz: URL
    }

    static func build() throws -> Built {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("peekfix-\(UUID().uuidString)")
        let payload = root.appendingPathComponent("payload")
        try fm.createDirectory(at: payload.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try "hello\n".write(to: payload.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "hi\n".write(to: payload.appendingPathComponent("sub/b.txt"), atomically: true, encoding: .utf8)

        let zip = root.appendingPathComponent("fixture.zip")
        try run("/usr/bin/zip", ["-r", "-q", zip.path, "a.txt", "sub"], cwd: payload)

        let targz = root.appendingPathComponent("fixture.tar.gz")
        try run("/usr/bin/tar", ["-czf", targz.path, "-C", payload.path, "a.txt", "sub"], cwd: nil)

        return Built(root: root, zip: zip, targz: targz)
    }

    static func cleanup(_ built: Built) {
        try? FileManager.default.removeItem(at: built.root)
    }

    private static func run(_ launchPath: String, _ args: [String], cwd: URL?) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        if let cwd { p.currentDirectoryURL = cwd }
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "ArchiveFixtures", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(launchPath) failed"])
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add PeekCore/Tests/PeekCoreTests/ArchiveFixtures.swift
git commit -m "test: add runtime archive fixture builder"
```

---

## Task 4: ArchiveSource via libarchive (TDD)

**Files:**
- Create: `PeekCore/Tests/PeekCoreTests/ArchiveSourceTests.swift`
- Create: `PeekCore/Sources/PeekCore/ArchiveSource.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import PeekCore

final class ArchiveSourceTests: XCTestCase {
    func testListsZipEntriesWithSizes() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        let contents = try ArchiveSource(url: fix.zip).read()
        let names = Set(contents.items.map(\.name))
        XCTAssertTrue(names.contains("a.txt"), "names were \(names)")
        XCTAssertTrue(names.contains("sub/b.txt"), "names were \(names)")

        let aFile = contents.items.first { $0.name == "a.txt" }
        XCTAssertEqual(aFile?.isDirectory, false)
        XCTAssertEqual(aFile?.sizeBytes, 6)
        XCTAssertEqual(contents.totalSize, 9) // 6 + 3, directories excluded
    }

    func testListsTarGzEntries() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        let contents = try ArchiveSource(url: fix.targz).read()
        let names = Set(contents.items.map(\.name))
        XCTAssertTrue(names.contains("a.txt"), "names were \(names)")
        XCTAssertTrue(names.contains("sub/b.txt"), "names were \(names)")
    }

    func testCorruptArchiveThrowsCannotRead() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("bad-\(UUID().uuidString).zip")
        try Data("not a real archive".utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertThrowsError(try ArchiveSource(url: tmp).read()) { error in
            guard case ContentSourceError.cannotRead = error else {
                return XCTFail("expected cannotRead, got \(error)")
            }
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd PeekCore && swift test --filter ArchiveSourceTests`
Expected: FAIL — `cannot find 'ArchiveSource' in scope`.

- [ ] **Step 3: Write the implementation**

Create `PeekCore/Sources/PeekCore/ArchiveSource.swift`:

```swift
import Foundation
import CLibArchive

public struct ArchiveSource: ContentSource {
    public let url: URL
    public init(url: URL) { self.url = url }

    private static let OK: Int32 = 0          // ARCHIVE_OK
    private static let EOF: Int32 = 1         // ARCHIVE_EOF
    private static let AE_IFMT: UInt16 = 0o170000
    private static let AE_IFDIR: UInt16 = 0o040000

    public func read() throws -> PreviewContents {
        guard let archive = archive_read_new() else {
            throw ContentSourceError.cannotRead("Could not allocate archive reader")
        }
        defer { archive_read_free(archive) }
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)

        let openResult = url.path.withCString { archive_read_open_filename(archive, $0, 10240) }
        guard openResult == Self.OK else {
            throw ContentSourceError.cannotRead(Self.errorString(archive) ?? "Could not open archive")
        }

        var items: [PreviewItem] = []
        var total: Int64 = 0
        while true {
            var entry: OpaquePointer?
            let result = archive_read_next_header(archive, &entry)
            if result == Self.EOF { break }
            guard result == Self.OK, let entry else {
                throw ContentSourceError.cannotRead(Self.errorString(archive) ?? "Corrupt archive entry")
            }
            guard let rawName = archive_entry_pathname(entry) else {
                _ = archive_read_data_skip(archive)
                continue
            }
            let path = String(cString: rawName)
            let filetype = archive_entry_filetype(entry)
            let isDir = (filetype & Self.AE_IFMT) == Self.AE_IFDIR || path.hasSuffix("/")
            let size = Int64(archive_entry_size(entry))
            let mtime = archive_entry_mtime(entry)
            let name = Self.displayName(path)
            if !name.isEmpty {
                items.append(PreviewItem(
                    name: name,
                    isDirectory: isDir,
                    sizeBytes: size,
                    modified: mtime > 0 ? Date(timeIntervalSince1970: TimeInterval(mtime)) : nil
                ))
                if !isDir { total += size }
            }
            _ = archive_read_data_skip(archive)
        }
        items.sort(by: FolderSource.order)
        return PreviewContents(items: items, totalSize: total)
    }

    private static func errorString(_ archive: OpaquePointer) -> String? {
        guard let c = archive_error_string(archive) else { return nil }
        let s = String(cString: c)
        return s.isEmpty ? nil : s
    }

    /// Archive entries are full paths ("sub/b.txt"); show them trimmed of a trailing slash.
    static func displayName(_ path: String) -> String {
        var p = path
        if p.hasSuffix("/") { p.removeLast() }
        return p
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd PeekCore && swift test --filter ArchiveSourceTests`
Expected: PASS (3 tests). If `testCorruptArchiveThrowsCannotRead` fails because libarchive returns a warning rather than a fatal open error, the read loop's `archive_read_next_header` guard still throws `cannotRead` — both paths are covered.

- [ ] **Step 5: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add PeekCore/Sources/PeekCore/ArchiveSource.swift PeekCore/Tests/PeekCoreTests/ArchiveSourceTests.swift
git commit -m "feat: ArchiveSource lists archive entries via libarchive"
```

---

## Task 5: SourceFactory (TDD)

**Files:**
- Create: `PeekCore/Tests/PeekCoreTests/SourceFactoryTests.swift`
- Modify: `PeekCore/Sources/PeekCore/SourceFactory.swift` (replace Task 1 placeholder)

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import PeekCore

final class SourceFactoryTests: XCTestCase {
    private func tempDir() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("sf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testFolderReturnsFolderSource() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertTrue(SourceFactory.source(for: dir) is FolderSource)
    }

    func testArchiveExtensionsReturnArchiveSource() {
        for name in ["x.zip", "x.tar", "x.tgz", "x.tar.gz", "x.gz"] {
            let url = URL(fileURLWithPath: "/tmp/\(name)")
            XCTAssertTrue(SourceFactory.source(for: url) is ArchiveSource, "\(name)")
        }
    }

    func testUnsupportedReturnsNil() {
        XCTAssertNil(SourceFactory.source(for: URL(fileURLWithPath: "/tmp/note.txt")))
        XCTAssertNil(SourceFactory.source(for: URL(fileURLWithPath: "/tmp/image.png")))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd PeekCore && swift test --filter SourceFactoryTests`
Expected: FAIL — placeholder returns nil so `testFolderReturnsFolderSource` and the archive cases fail.

- [ ] **Step 3: Write the implementation (replace the placeholder file)**

```swift
import Foundation

public enum SourceFactory {
    /// Single-extension archive types. `.tar.gz` is handled by suffix below.
    public static let archiveExtensions: Set<String> = ["zip", "zipx", "tar", "gz", "tgz"]

    public static func source(for url: URL) -> ContentSource? {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            return FolderSource(url: url)
        }
        let lastComponent = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        if lastComponent.hasSuffix(".tar.gz") || archiveExtensions.contains(ext) {
            return ArchiveSource(url: url)
        }
        return nil
    }
}
```

- [ ] **Step 4: Run the full core suite**

Run: `cd PeekCore && swift test`
Expected: PASS — all FolderSource, ArchiveSource, SourceFactory tests green.

- [ ] **Step 5: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add PeekCore/Sources/PeekCore/SourceFactory.swift PeekCore/Tests/PeekCoreTests/SourceFactoryTests.swift
git commit -m "feat: SourceFactory routes folders/archives to the right source"
```

---

## Task 6: App scaffold (XcodeGen project that builds and runs as an agent)

**Files:**
- Create: `App/project.yml`
- Create: `App/Peek/Info.plist`
- Create: `App/Peek/Peek.entitlements`
- Create: `App/Peek/main.swift`
- Create: `App/Peek/AppDelegate.swift`
- Modify: `.gitignore`

- [ ] **Step 1: Ensure XcodeGen is installed**

Run: `which xcodegen || brew install xcodegen`
Expected: a path to `xcodegen` (installs if missing).

- [ ] **Step 2: Create `App/project.yml`**

```yaml
name: Peek
options:
  bundleIdPrefix: com.bubbleee030
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
packages:
  PeekCore:
    path: ../PeekCore
targets:
  Peek:
    type: application
    platform: macOS
    sources:
      - path: Peek
    dependencies:
      - package: PeekCore
        product: PeekCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.bubbleee030.peek
        PRODUCT_NAME: Peek
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        GENERATE_INFOPLIST_FILE: NO
        INFOPLIST_FILE: Peek/Info.plist
        CODE_SIGN_ENTITLEMENTS: Peek/Peek.entitlements
        CODE_SIGN_STYLE: Automatic
        ENABLE_HARDENED_RUNTIME: YES
        SWIFT_VERSION: "6.0"
        SWIFT_STRICT_CONCURRENCY: complete
schemes:
  Peek:
    build:
      targets:
        Peek: all
    run:
      config: Debug
```

- [ ] **Step 3: Create `App/Peek/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Peek</string>
    <key>CFBundleDisplayName</key>
    <string>Peek</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Peek reads the current Finder selection so it can show you what is inside the folder or archive you have highlighted.</string>
</dict>
</plist>
```

- [ ] **Step 4: Create `App/Peek/Peek.entitlements`**

App Sandbox is intentionally OFF (a global event tap and free Apple Events to Finder are incompatible with the sandbox for a personal utility). Hardened runtime is ON, so Apple Events need this entitlement:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Create `App/Peek/main.swift`**

```swift
import AppKit

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon; reinforces LSUIElement
app.run()
```

- [ ] **Step 6: Create a minimal `App/Peek/AppDelegate.swift` (expanded in later tasks)**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Peek launched")
    }
}
```

- [ ] **Step 7: Ignore the generated project**

Append to `.gitignore`:

```
App/Peek.xcodeproj/
```

- [ ] **Step 8: Generate and build**

Run:
```bash
cd /Users/bubble/Vscode/Preview/App && xcodegen generate
xcodebuild -project Peek.xcodeproj -scheme Peek -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```
Expected: `** BUILD SUCCEEDED **`. (`CODE_SIGNING_ALLOWED=NO` lets CI/headless builds pass; in Xcode you'll select your team once for signed runs.)

- [ ] **Step 9: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add App/project.yml App/Peek/Info.plist App/Peek/Peek.entitlements App/Peek/main.swift App/Peek/AppDelegate.swift .gitignore
git commit -m "feat: scaffold Peek app target (agent app that builds)"
```

---

## Task 7: Preview view + view model + controller (wired to a manual trigger)

Build the UI first and prove it works via a temporary menu item, before adding the event tap.

**Files:**
- Create: `App/Peek/PreviewViewModel.swift`
- Create: `App/Peek/PreviewView.swift`
- Create: `App/Peek/PreviewController.swift`
- Modify: `App/Peek/AppDelegate.swift`

- [ ] **Step 1: Create `App/Peek/PreviewViewModel.swift`**

```swift
import Foundation
import PeekCore

@MainActor
final class PreviewViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(PreviewContents)
        case failed(String)
    }

    let url: URL
    @Published private(set) var state: State = .loading

    init(url: URL) { self.url = url }

    var title: String { url.lastPathComponent }

    func load() {
        guard let source = SourceFactory.source(for: url) else {
            state = .failed("Peek can't preview this item.")
            return
        }
        Task.detached(priority: .userInitiated) {
            do {
                let contents = try source.read()
                await MainActor.run { self.state = .loaded(contents) }
            } catch let error as ContentSourceError {
                await MainActor.run { self.state = .failed(Self.describe(error)) }
            } catch {
                await MainActor.run { self.state = .failed(error.localizedDescription) }
            }
        }
    }

    private static func describe(_ error: ContentSourceError) -> String {
        switch error {
        case .cannotRead(let message): return message
        case .unsupported(let message): return message
        }
    }
}
```

- [ ] **Step 2: Create `App/Peek/PreviewView.swift`**

```swift
import SwiftUI
import AppKit
import PeekCore

struct PreviewView: View {
    @ObservedObject var model: PreviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: model.url.path))
                .resizable().frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title).font(.headline).lineLimit(1)
                summary
            }
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder private var summary: some View {
        if case let .loaded(contents) = model.state {
            Text("\(contents.count) item\(contents.count == 1 ? "" : "s") • \(Self.size(contents.totalSize))")
                .font(.subheadline).foregroundStyle(.secondary)
        } else {
            Text(" ").font(.subheadline)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
        case .loaded(let contents):
            if contents.items.isEmpty {
                Text("Empty").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(contents.items) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.isDirectory ? "folder" : "doc")
                            .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                        Text(item.name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        if !item.isDirectory {
                            Text(Self.size(item.sizeBytes)).foregroundStyle(.secondary)
                                .font(.callout).monospacedDigit()
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
```

- [ ] **Step 3: Create `App/Peek/PreviewController.swift`**

```swift
import AppKit
import SwiftUI

@MainActor
final class PreviewController {
    private var panel: NSPanel?
    private var keyMonitor: Any?

    func show(url: URL) {
        close()

        let model = PreviewViewModel(url: url)
        let hosting = NSHostingView(rootView: PreviewView(model: model))

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        positionNearMouse(panel)

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        model.load()

        // Esc or space closes; click-away (resignKey) closes.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 || event.keyCode == 49 { // esc / space
                self?.close()
                return nil
            }
            return event
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(resigned(_:)),
            name: NSWindow.didResignKeyNotification, object: panel
        )
    }

    @objc private func resigned(_ note: Notification) { close() }

    func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let panel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: panel)
            panel.orderOut(nil)
        }
        panel = nil
    }

    private func positionNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { panel.center(); return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: min(max(mouse.x - size.width / 2, visible.minX), visible.maxX - size.width),
            y: min(max(mouse.y - size.height / 2, visible.minY), visible.maxY - size.height)
        )
        panel.setFrameOrigin(origin)
    }
}
```

- [ ] **Step 4: Add a temporary trigger in `App/Peek/AppDelegate.swift`**

Replace the file with:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let previewController = PreviewController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Temporary manual trigger to verify the panel before the event tap exists.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Peek")
        let menu = NSMenu()
        menu.addItem(withTitle: "Preview Home Folder…", action: #selector(previewHome), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Peek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func previewHome() {
        previewController.show(url: FileManager.default.homeDirectoryForCurrentUser)
    }
}
```

- [ ] **Step 5: Regenerate, build, and manually verify**

Run:
```bash
cd /Users/bubble/Vscode/Preview/App && xcodegen generate
xcodebuild -project Peek.xcodeproj -scheme Peek -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```
Expected: `** BUILD SUCCEEDED **`.

Manual check: open the built app (path printed by xcodebuild, under `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/Peek.app`) with `open <path>`. Click the menu-bar **eye → Preview Home Folder…**. A panel appears listing your home folder's contents with sizes, folders first. Press **space** or **Esc**, or click away → it closes.

- [ ] **Step 6: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add App/Peek/PreviewViewModel.swift App/Peek/PreviewView.swift App/Peek/PreviewController.swift App/Peek/AppDelegate.swift
git commit -m "feat: SwiftUI preview panel with manual menu-bar trigger"
```

---

## Task 8: FinderContext — read the Finder selection via Apple Events

**Files:**
- Create: `App/Peek/FinderContext.swift`

- [ ] **Step 1: Create the file**

```swift
import AppKit
import PeekCore

/// Polls Finder's current selection via Apple Events, but only while Finder is
/// frontmost, so the spacebar tap can decide instantly from a cached value.
@MainActor
final class FinderContext {
    private var timer: Timer?
    private let script: NSAppleScript?
    private(set) var selectedURLs: [URL] = []

    init() {
        let source = """
        tell application "Finder"
            set out to ""
            repeat with theItem in (selection as alias list)
                set out to out & (POSIX path of theItem) & linefeed
            end repeat
            return out
        end tell
        """
        script = NSAppleScript(source: source)
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder",
              let script else { return }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else { return } // e.g. Automation permission not yet granted
        let text = result.stringValue ?? ""
        selectedURLs = text
            .split(separator: "\n")
            .map { URL(fileURLWithPath: String($0)) }
    }

    /// The single selected item, only if it is a folder or supported archive.
    var previewableSelection: URL? {
        guard selectedURLs.count == 1, let url = selectedURLs.first else { return nil }
        return SourceFactory.source(for: url) != nil ? url : nil
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run:
```bash
cd /Users/bubble/Vscode/Preview/App && xcodegen generate
xcodebuild -project Peek.xcodeproj -scheme Peek -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add App/Peek/FinderContext.swift
git commit -m "feat: FinderContext polls the Finder selection via Apple Events"
```

---

## Task 9: FocusGuard — don't hijack space while renaming

**Files:**
- Create: `App/Peek/FocusGuard.swift`

- [ ] **Step 1: Create the file**

```swift
import ApplicationServices

/// Returns true when the focused UI element is a text field/area (e.g. renaming
/// a file in Finder), so the tap leaves space alone for typing.
struct FocusGuard {
    var isEditingText: Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return false }
        let element = focused as! AXUIElement

        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
              let role = roleValue as? String else { return false }

        return role == (kAXTextFieldRole as String)
            || role == (kAXTextAreaRole as String)
            || role == (kAXComboBoxRole as String)
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `cd /Users/bubble/Vscode/Preview/App && xcodegen generate && xcodebuild -project Peek.xcodeproj -scheme Peek -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add App/Peek/FocusGuard.swift
git commit -m "feat: FocusGuard avoids hijacking space in text fields"
```

---

## Task 10: KeyTap — intercept space for folders/archives only

**Files:**
- Create: `App/Peek/KeyTap.swift`
- Modify: `App/Peek/AppDelegate.swift`

- [ ] **Step 1: Create `App/Peek/KeyTap.swift`**

```swift
import AppKit
import ApplicationServices

@MainActor
final class KeyTap {
    private let finder: FinderContext
    private let onPreview: (URL) -> Void
    private let focusGuard = FocusGuard()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let spaceKeyCode: Int64 = 49

    init(finder: FinderContext, onPreview: @escaping (URL) -> Void) {
        self.finder = finder
        self.onPreview = onPreview
    }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    @discardableResult
    func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Returns false if Accessibility isn't granted yet (after prompting).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard Self.hasAccessibility else { requestAccessibility(); return false }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return MainActor.assumeIsolated { me.handle(type: type, event: event) }
            },
            userInfo: refcon
        ) else {
            NSLog("Peek: failed to create event tap")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passthrough = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return passthrough
        }
        guard type == .keyDown,
              event.getIntegerValueField(.keyboardEventKeycode) == Self.spaceKeyCode else {
            return passthrough
        }
        // Plain space only — let shortcuts through.
        let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
        guard event.flags.intersection(modifiers).isEmpty else { return passthrough }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return passthrough }
        guard !focusGuard.isEditingText else { return passthrough }
        guard let url = finder.previewableSelection else { return passthrough }

        onPreview(url)
        return nil // consume — native Quick Look does not open
    }
}
```

- [ ] **Step 2: Wire it up — replace `App/Peek/AppDelegate.swift`**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let finderContext = FinderContext()
    let previewController = PreviewController()
    private lazy var keyTap = KeyTap(finder: finderContext) { [weak self] url in
        self?.previewController.show(url: url)
    }
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        finderContext.start()
        let granted = keyTap.start()

        // Temporary status item (replaced by MenuBarController in Task 11).
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Peek")
        let menu = NSMenu()
        menu.addItem(withTitle: granted ? "Accessibility: granted" : "Grant Accessibility…",
                     action: #selector(grant), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Peek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func grant() {
        keyTap.requestAccessibility()
        _ = keyTap.start()
    }
}
```

- [ ] **Step 3: Build, then run and manually verify the core feature**

Run:
```bash
cd /Users/bubble/Vscode/Preview/App && xcodegen generate
xcodebuild -project Peek.xcodeproj -scheme Peek -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```
Expected: `** BUILD SUCCEEDED **`.

Manual checklist (open the built `Peek.app`, grant Accessibility when prompted via the menu, and grant Automation when first prompted):
- In Finder, select a **folder**, press **space** → Peek's contents panel appears (not the system folder icon). ✅
- Select a **.zip** or **.tar.gz**, press space → entries listed. ✅
- Select an **image / PDF / text file**, press space → **native Quick Look** opens as usual. ✅
- Select **two** items, press space → native Quick Look (Peek passes through). ✅
- Start **renaming** a folder (Return), press space → a space is typed, panel does **not** appear. ✅
- Press space again / Esc / click away with the panel open → it closes. ✅

- [ ] **Step 4: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add App/Peek/KeyTap.swift App/Peek/AppDelegate.swift
git commit -m "feat: KeyTap consumes space for folders/archives, passes through otherwise"
```

---

## Task 11: MenuBarController — permissions, launch at login, hide icon

**Files:**
- Create: `App/Peek/MenuBarController.swift`
- Modify: `App/Peek/AppDelegate.swift`

- [ ] **Step 1: Create `App/Peek/MenuBarController.swift`**

```swift
import AppKit
import ServiceManagement

@MainActor
final class MenuBarController: NSObject {
    private let keyTap: KeyTap
    private var statusItem: NSStatusItem?
    private let defaults = UserDefaults.standard
    private static let showIconKey = "showMenuBarIcon"

    init(keyTap: KeyTap) {
        self.keyTap = keyTap
        super.init()
        if defaults.object(forKey: Self.showIconKey) == nil {
            defaults.set(true, forKey: Self.showIconKey)
        }
        if defaults.bool(forKey: Self.showIconKey) { installItem() }
    }

    private func installItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Peek")
        statusItem = item
        rebuildMenu()
    }

    func rebuildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()

        let accessibilityOK = KeyTap.hasAccessibility
        let accItem = NSMenuItem(
            title: accessibilityOK ? "Accessibility: granted" : "Grant Accessibility…",
            action: accessibilityOK ? nil : #selector(grantAccessibility), keyEquivalent: ""
        )
        accItem.target = self
        menu.addItem(accItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(title: "Hide Menu-Bar Icon", action: #selector(hideIcon), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        let quit = NSMenuItem(title: "Quit Peek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func grantAccessibility() {
        keyTap.requestAccessibility()
        _ = keyTap.start()
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() }
            else { try service.register() }
        } catch {
            NSLog("Peek: launch-at-login toggle failed: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func hideIcon() {
        defaults.set(false, forKey: Self.showIconKey)
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }
}
```

- [ ] **Step 2: Replace `App/Peek/AppDelegate.swift` to use MenuBarController**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let finderContext = FinderContext()
    let previewController = PreviewController()
    private lazy var keyTap = KeyTap(finder: finderContext) { [weak self] url in
        self?.previewController.show(url: url)
    }
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        finderContext.start()
        _ = keyTap.start()
        menuBar = MenuBarController(keyTap: keyTap)
    }
}
```

- [ ] **Step 3: Build and manually verify the menu**

Run: `cd /Users/bubble/Vscode/Preview/App && xcodegen generate && xcodebuild -project Peek.xcodeproj -scheme Peek -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`.

Manual check (run the built app): menu-bar **eye** shows Accessibility status, a working **Launch at Login** toggle (check it, reboot/relogin optional to confirm), **Hide Menu-Bar Icon** (removes the icon; re-enable with `defaults write com.bubbleee030.peek showMenuBarIcon -bool YES` then relaunch), and **Quit**.

- [ ] **Step 4: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add App/Peek/MenuBarController.swift App/Peek/AppDelegate.swift
git commit -m "feat: menu bar with permissions, launch-at-login, hide-icon"
```

---

## Task 12: README and developer docs

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

````markdown
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
   "Grant Accessibility…" item, then re-open the menu).
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
````

- [ ] **Step 2: Commit**

```bash
cd /Users/bubble/Vscode/Preview
git add README.md
git commit -m "docs: add README with build and permission instructions"
```

---

## Task 13: Publish to GitHub

**Files:** none (git/remote operations).

- [ ] **Step 1: Create or attach the remote and push**

Run (handles both "repo already exists" and "needs creating"):

```bash
cd /Users/bubble/Vscode/Preview
if gh repo view bubbleee030/Peek >/dev/null 2>&1; then
  git remote add origin https://github.com/bubbleee030/Peek.git 2>/dev/null || git remote set-url origin https://github.com/bubbleee030/Peek.git
  git push -u origin main
else
  gh repo create bubbleee030/Peek --public --source . --remote origin --push
fi
```
Expected: branch `main` pushed; `gh repo view bubbleee030/Peek` shows the files.

- [ ] **Step 2: Verify**

Run: `gh repo view bubbleee030/Peek --web` (or `gh repo view bubbleee030/Peek`)
Expected: README renders; `PeekCore/`, `App/`, and `docs/` are present.

---

## Self-Review

**Spec coverage:**
- Press space → folder contents: Tasks 7, 8, 10. ✅
- Archives without extraction (zip/tar/tar.gz/tgz/gz): Tasks 3–5, libarchive shim Task 1. ✅
- Pass-through for other types / multi-select / empty: Task 10 logic + manual checklist. ✅
- Flat read-only list, folders first, size + count header: Tasks 2, 7. ✅
- Background agent, menu-bar icon, hideable, launch-at-login: Tasks 6, 11. ✅
- Permissions (Accessibility, Automation) with UX: Tasks 10, 11; usage strings Task 6. ✅
- Don't hijack space while renaming: Task 9. ✅
- Tap auto-re-enable on timeout: Task 10. ✅
- Error handling (unreadable/corrupt/empty/large off-main-thread): FolderSource/ArchiveSource throw (Tasks 2, 4); ViewModel renders `.failed` and loads off-main (Task 7). ✅
- TDD on readers + manual checklist for integration: Tasks 2, 4, 5 (unit), Task 10 (manual). ✅
- Xcode project, stable bundle id, libarchive linked: Tasks 1, 6. ✅
- README documents build/permissions/hide-icon `defaults` command: Task 12. ✅
- Push to github.com/bubbleee030/Peek: Task 13. ✅

**Note on the "5,000-row cap" mentioned in the spec's large-folder handling:** deferred as YAGNI for v1 — folders and archives are read off the main thread (Task 7) so the UI stays responsive; SwiftUI `List` is lazy. If a pathological folder ever proves slow in the manual checklist, add a cap then.

**Placeholder scan:** No TBD/TODO; every code step contains complete code; every command has expected output.

**Type consistency:** `ContentSource.read() -> PreviewContents`, `PreviewItem(name:isDirectory:sizeBytes:modified:)`, `FolderSource.order`, `SourceFactory.source(for:)`, `FinderContext.previewableSelection`, `KeyTap.start() -> Bool`, `KeyTap.hasAccessibility`, `PreviewController.show(url:)`, `PreviewViewModel.State` — all referenced consistently across tasks.
