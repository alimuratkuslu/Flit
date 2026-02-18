# Flit — Product Requirements Document

## Overview

**Flit** is a lightweight macOS menu bar app that lets users instantly switch to any running application using `Option+1` through `Option+9` keyboard shortcuts. Each number slot maps to a specific app (by bundle ID). If the target app is not running, the shortcut does nothing.

**Comparable apps**: yabai, Aerospace, Rectangle — but with zero window management. Pure app-focus switching only.

---

## Requirements

### Functional
- Global keyboard shortcuts: `⌥1` through `⌥9`
- Each slot maps to one app (assigned by user)
- Pressing a slot: immediately focuses that app (brings to front, unhides if hidden)
- If app is not running: silently do nothing
- Assignments persist across reboots (UserDefaults)
- Settings panel accessible from menu bar icon
- Settings panel lists all installed apps in a dropdown per slot
- App requires Accessibility permission (for CGEventTap); prompts user if missing

### Non-Functional
- Runs as a menu bar only app (no Dock icon, `LSUIElement = YES`)
- No App Sandbox (required for CGEventTap + arbitrary app activation)
- Minimum macOS 13.0 (Ventura)
- Swift / SwiftUI + AppKit
- Consumes the Option+N key event (prevents it reaching other apps)

---

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI (settings panel) + AppKit (status bar, window management) |
| Hotkeys | CGEventTap (Accessibility API) |
| App activation | NSRunningApplication + NSWorkspace |
| Persistence | UserDefaults |
| Build | Xcode project (no SPM needed) |

---

## Project Structure

```
tile-manager/
  Flit.xcodeproj/
  Flit/
    App/
      FlitApp.swift          ← @main entry, wires AppDelegate
      AppDelegate.swift           ← lifecycle, permission check, wires singletons
    Core/
      HotkeyManager.swift         ← CGEventTap global listener
      AppSwitcherService.swift    ← activate running app by bundle ID
      AppListProvider.swift       ← scans /Applications for installed apps
    State/
      SettingsStore.swift         ← UserDefaults-backed ObservableObject
    UI/
      StatusBarController.swift   ← NSStatusItem, NSMenu, opens settings window
      SettingsView.swift          ← SwiftUI 9-row settings window
      AppPickerRow.swift          ← single slot row with app dropdown
      PermissionBannerView.swift  ← shown in settings if accessibility not granted
    Resources/
      Info.plist                  ← LSUIElement=YES, NSAccessibilityUsageDescription
      Flit.entitlements      ← App Sandbox = false
      Assets.xcassets/
```

---

## Xcode Project Setup

### 1. Create Project
- macOS > App template
- Product Name: `Flit`, Bundle ID: `com.<name>.flit`
- Interface: SwiftUI, Language: Swift
- Save inside `/Users/alimuratkuslu/Desktop/tile-manager/`

### 2. Target Settings
- Minimum Deployment: **macOS 13.0**
- **Disable App Sandbox** (required for CGEventTap and app activation)
- Keep Hardened Runtime enabled
- Swift Strict Concurrency: `targeted` (not `complete`)

### 3. Info.plist Keys
```xml
<key>LSUIElement</key><true/>
<key>NSAccessibilityUsageDescription</key>
<string>Flit needs Accessibility access to intercept global keyboard shortcuts.</string>
```

### 4. Entitlements
```xml
<key>com.apple.security.app-sandbox</key><false/>
```

---

## File-by-File Implementation

### `FlitApp.swift`
```swift
import SwiftUI

@main
struct FlitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }  // prevents "no scenes" warning; no default window
    }
}
```

---

### `AppDelegate.swift`
```swift
import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(
            store: SettingsStore.shared,
            listProvider: AppListProvider.shared
        )
        if !AXIsProcessTrusted() {
            statusBarController.showPermissionAlert()  // shows alert → quits
        } else {
            hotkeyManager = HotkeyManager(
                store: SettingsStore.shared,
                switcher: AppSwitcherService.shared
            )
            hotkeyManager.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
    }
}
```

---

### `HotkeyManager.swift` ⚠️ Most Complex File

**Key codes for number row (ANSI US keyboard — hardware scan codes, not ASCII):**

| Key | Code | Key | Code |
|-----|------|-----|------|
| 1   | 18   | 6   | 22   |
| 2   | 19   | 7   | 26   |
| 3   | 20   | 8   | 28   |
| 4   | 21   | 9   | 25   |
| 5   | 23   |     |      |

> Note: 5 and 6 are non-sequential (23, 22). 7 and 9 are also non-sequential (26, 25).
> Verify with Karabiner-EventViewer if shortcuts feel wrong on your keyboard.

```swift
import Cocoa

final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let store: SettingsStore
    private let switcher: AppSwitcherService

    static let keyCodeToSlot: [CGKeyCode: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
        22: 6, 26: 7, 28: 8, 25: 9
    ]

    init(store: SettingsStore, switcher: AppSwitcherService) {
        self.store = store
        self.switcher = switcher
    }

    func start() {
        // passUnretained: AppDelegate already holds HotkeyManager strongly
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,          // active tap = can consume events
            eventsOfInterest: eventMask,
            callback: eventTapCallback,    // C-compatible free function (see below)
            userInfo: selfPtr
        ) else {
            print("HotkeyManager: Failed to create event tap. Missing Accessibility permission.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEventTapEnable(tap, true)
    }

    func stop() {
        if let tap = eventTap { CGEventTapEnable(tap, false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func activateSlot(_ slot: Int) {
        guard let bundleID = store.assignment(forSlot: slot) else { return }
        switcher.activate(bundleID: bundleID)
    }
}

// MUST be a C-compatible free function — closures with captures won't work as CFunctionPointer
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    guard let ptr = userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()

    // Re-enable tap if system disabled it (happens after sleep or screen lock)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = manager.eventTap { CGEventTapEnable(tap, true) }
        return nil
    }

    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let flags = event.flags
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

    // Pure Option+N only — no Cmd, Ctrl, or Shift
    let optionOnly = flags.contains(.maskAlternate)
                  && !flags.contains(.maskCommand)
                  && !flags.contains(.maskControl)
                  && !flags.contains(.maskShift)

    guard optionOnly, let slot = HotkeyManager.keyCodeToSlot[keyCode] else {
        return Unmanaged.passRetained(event)  // not our shortcut — pass through
    }

    // Activate on main thread (CGEventTap runs on the RunLoop thread)
    DispatchQueue.main.async { manager.activateSlot(slot) }

    return nil  // consume event — do NOT pass to other apps
}
```

**Critical implementation rules:**
1. Callback MUST be a C-compatible free function (not a method or closure with captures)
2. `passUnretained` for `self` via `userInfo` — AppDelegate holds strong ref, no double-retain needed
3. `return nil` consumes the event; `return Unmanaged.passRetained(event)` passes it through
4. Always handle `tapDisabledByTimeout` to re-enable the tap after sleep/lock

---

### `AppSwitcherService.swift`
```swift
import Cocoa

final class AppSwitcherService {
    static let shared = AppSwitcherService()
    private init() {}

    func activate(bundleID: String) {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else { return }  // not running → silently do nothing

        if app.isHidden { app.unhide() }

        if #available(macOS 14.0, *) {
            app.activate(options: [])
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
```

---

### `SettingsStore.swift`
```swift
import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private init() { loadAll() }

    @Published private(set) var assignments: [Int: String] = [:]
    private let keyPrefix = "slot_"

    func assignment(forSlot slot: Int) -> String? {
        assignments[slot]
    }

    func setAssignment(bundleID: String?, forSlot slot: Int) {
        if let id = bundleID, !id.isEmpty {
            assignments[slot] = id
            UserDefaults.standard.set(id, forKey: keyPrefix + "\(slot)")
        } else {
            assignments.removeValue(forKey: slot)
            UserDefaults.standard.removeObject(forKey: keyPrefix + "\(slot)")
        }
    }

    private func loadAll() {
        assignments = Dictionary(uniqueKeysWithValues:
            (1...9).compactMap { slot -> (Int, String)? in
                guard let id = UserDefaults.standard.string(forKey: keyPrefix + "\(slot)")
                else { return nil }
                return (slot, id)
            }
        )
    }
}
```

---

### `AppListProvider.swift`
```swift
import AppKit
import Combine

struct AppInfo: Identifiable, Hashable {
    let id: String        // bundle identifier (e.g. "com.apple.Safari")
    let name: String      // display name
    let icon: NSImage
    let bundleURL: URL
}

final class AppListProvider: ObservableObject {
    static let shared = AppListProvider()
    private init() {}

    @Published private(set) var apps: [AppInfo] = []

    private let searchPaths: [URL] = [
        "/Applications",
        "\(NSHomeDirectory())/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        "/Applications/Utilities",
    ].map(URL.init(fileURLWithPath:))

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let found = self.scan().sorted { $0.name < $1.name }
            DispatchQueue.main.async { self.apps = found }
        }
    }

    private func scan() -> [AppInfo] {
        var result: [AppInfo] = []
        var seen = Set<String>()

        for base in searchPaths {
            let items = (try? FileManager.default.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )) ?? []

            for url in items where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let id = bundle.bundleIdentifier,
                      !seen.contains(id)
                else { continue }

                let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                        ?? bundle.infoDictionary?["CFBundleName"] as? String
                        ?? url.deletingPathExtension().lastPathComponent

                let icon = NSWorkspace.shared.icon(forFile: url.path)
                result.append(AppInfo(id: id, name: name, icon: icon, bundleURL: url))
                seen.insert(id)
            }
        }
        return result
    }
}
```

---

### `StatusBarController.swift`
```swift
import AppKit
import SwiftUI

final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var settingsWindowController: NSWindowController?
    private let store: SettingsStore
    private let listProvider: AppListProvider

    init(store: SettingsStore, listProvider: AppListProvider) {
        self.store = store
        self.listProvider = listProvider

        // Use SF Symbol as menu bar icon — isTemplate adapts to dark/light mode
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard",
                                           accessibilityDescription: "Flit")
        statusItem.button?.image?.isTemplate = true
        buildMenu()
    }

    // MARK: - Permission

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            Flit needs Accessibility access to intercept ⌥+Number shortcuts.

            Click 'Open Settings', grant access, then relaunch the app.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Quit")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
        NSApp.terminate(nil)
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: "Flit", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Flit",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Settings Window

    @objc private func openSettings() {
        listProvider.refresh()

        if settingsWindowController == nil {
            let view = SettingsView()
                .environmentObject(store)
                .environmentObject(listProvider)

            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Flit Settings"
            window.contentViewController = NSHostingController(rootView: view)
            window.center()
            window.isReleasedWhenClosed = false   // CRITICAL: retain for reuse
            settingsWindowController = NSWindowController(window: window)
        }

        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

---

### `SettingsView.swift`
```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var listProvider: AppListProvider
    @State private var isTrusted = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isTrusted {
                PermissionBannerView().padding()
            }

            Text("Slot Assignments")
                .font(.headline)
                .padding([.horizontal, .top], 16)
            Text("Assign an app to each ⌥+Number slot. Press the shortcut to instantly switch to that app.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(1...9, id: \.self) { slot in
                        AppPickerRow(slot: slot)
                            .environmentObject(store)
                            .environmentObject(listProvider)
                        if slot < 9 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.defaultAction)
                    .padding()
            }
        }
        .frame(width: 480, height: 520)
        .onAppear { isTrusted = AXIsProcessTrusted() }
    }
}
```

---

### `AppPickerRow.swift`
```swift
import SwiftUI

struct AppPickerRow: View {
    let slot: Int
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var listProvider: AppListProvider
    @State private var selectedBundleID: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Text("⌥\(slot)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 36)
                .padding(4)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(6)

            Picker("", selection: $selectedBundleID) {
                Text("— None —").tag("")
                ForEach(listProvider.apps) { app in
                    HStack(spacing: 6) {
                        Image(nsImage: app.icon)
                        Text(app.name)
                    }
                    .tag(app.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .onChange(of: selectedBundleID) { _, newValue in
                store.setAssignment(
                    bundleID: newValue.isEmpty ? nil : newValue,
                    forSlot: slot
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            selectedBundleID = store.assignment(forSlot: slot) ?? ""
        }
    }
}
```

---

### `PermissionBannerView.swift`
```swift
import SwiftUI

struct PermissionBannerView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.orange)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Permission Needed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Required to intercept ⌥+Number shortcuts globally.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}
```

---

## Build Order

### Phase 1 — Project Skeleton
- [ ] Create Xcode project (macOS > App, SwiftUI)
- [ ] Set `LSUIElement = YES` in Info.plist immediately
- [ ] Disable App Sandbox in entitlements
- [ ] Delete generated `ContentView.swift`
- [ ] Create folder groups: `App/`, `Core/`, `State/`, `UI/`
- [ ] Write minimal `FlitApp.swift` + stubbed `AppDelegate.swift`
- [ ] **Build & run** — confirm no Dock icon appears

### Phase 2 — State Layer
- [ ] Implement `SettingsStore.swift`
- [ ] Implement `AppListProvider.swift`
- [ ] Smoke test: print scanned app names to console from AppDelegate

### Phase 3 — Settings UI
- [ ] Implement `PermissionBannerView.swift`
- [ ] Implement `AppPickerRow.swift`
- [ ] Implement `SettingsView.swift`
- [ ] Implement `StatusBarController.swift`
- [ ] Wire into `AppDelegate` (skip HotkeyManager for now)
- [ ] **Build & run** — click menu bar, open Settings, verify 9 rows with real app icons and names

### Phase 4 — Global Hotkeys
- [ ] Implement `AppSwitcherService.swift`
- [ ] Implement `HotkeyManager.swift`
- [ ] Wire into `AppDelegate` with `AXIsProcessTrusted()` gate
- [ ] Grant Accessibility in System Settings > Privacy & Security, relaunch
- [ ] Assign app to slot 1, press `⌥1` — verify app switches to focus

### Phase 5 — Polish
- [ ] Handle `tapDisabledByTimeout` in callback (re-enable tap after sleep)
- [ ] Add proper menu bar template icon in Assets.xcassets
- [ ] Verify `⌘,` keyboard shortcut opens Settings
- [ ] Test all 9 slots

---

## Data Flow

```
[⌥+N pressed system-wide]
       │
       ▼
[CGEventTap callback — main RunLoop]
       │  return nil → event consumed (not passed to other apps)
       ▼
[DispatchQueue.main.async]
       │
       ▼
[HotkeyManager.activateSlot(N)]
       │
       ▼
[SettingsStore.assignment(forSlot: N)] ← UserDefaults
       │ bundleID: String?
       ▼
[AppSwitcherService.activate(bundleID:)]
       │
       ▼
[NSRunningApplication.runningApplications(withBundleIdentifier:)]
       │ found? → app.activate()
       │ not found? → do nothing
       ▼
[App comes to focus instantly]
```

---

## Known Gotchas

| Issue | Solution |
|---|---|
| CGEventTap callback must be C-compatible | Use free function + `Unmanaged` to pass `self` via `userInfo` |
| Key codes 5–9 are non-sequential | Use exact map: `5→23, 6→22, 7→26, 8→28, 9→25` |
| Tap disabled after sleep/lock screen | Handle `tapDisabledByTimeout` event type → call `CGEventTapEnable(tap, true)` |
| Opening settings from LSUIElement app | Must call `NSApp.activate(ignoringOtherApps: true)` |
| Settings window crashes on second open | Set `window.isReleasedWhenClosed = false` |
| `onChange(of:)` API changed macOS 14 | Use two-parameter form `{ _, newValue in }` (works on 13+) |
| Option+N types special chars on some keyboards | Acceptable tradeoff — consuming event is intentional behavior |
| `AXIsProcessTrusted()` caches after first call | Standard pattern: show alert → quit → user relaunches app |
| App Sandbox incompatible with CGEventTap | Sandbox MUST be disabled; distribute outside Mac App Store |

---

## Optional Post-MVP Enhancements

1. **Launch at Login** — `SMAppService.mainApp.register()` (macOS 13+), add checkbox to Settings
2. **Running app indicator** — green dot next to assigned app if currently running
3. **HUD overlay** — brief badge showing slot number when shortcut fires
4. **JSON config export/import** — sync slot assignments between machines
5. **Custom modifier key** — let user choose Control vs Option in Settings

---

## Critical Files Reference

| File | Purpose |
|---|---|
| `Flit/Core/HotkeyManager.swift` | CGEventTap, C callback, key code map, event consumption |
| `Flit/App/AppDelegate.swift` | Initialization order, permission gating, singleton ownership |
| `Flit/State/SettingsStore.swift` | Shared state (read by hotkey path, written by UI) |
| `Flit/UI/StatusBarController.swift` | Menu bar entry point, settings window lifecycle |
| `Flit/Core/AppListProvider.swift` | App scan, drives Settings picker content |
| `Flit/Resources/Info.plist` | `LSUIElement=YES`, accessibility usage description |

---

## Core Features Roadmap

### Tier 1 — High-Value, Straightforward

#### 1. Launch at Login
- **API:** `SMAppService.mainApp.register()` / `.unregister()` (macOS 13+, no helper needed)
- **UI:** Toggle checkbox in Settings panel below the slot list
- **Storage:** Persisted by the OS via `SMAppService`; no UserDefaults needed
- **Error handling:** Show alert if registration fails (sandboxed builds, revoked entitlement)

#### 2. Launch if Not Running
- **Per-slot toggle:** A checkbox on each `AppPickerRow` row — "Launch if not running"
- **Storage:** `UserDefaults` key `slot_launch_\(slot)` (Bool)
- **Behavior:** In `AppSwitcherService.activate()`, if `runningApplications` returns empty AND toggle is on, call `NSWorkspace.shared.openApplication(at: bundleURL, configuration: .init())`
- **Requires:** `AppInfo.bundleURL` already stored — look it up from `AppListProvider`

#### 3. Slot Summary in Menu Bar Menu
- **UI:** Below the "Settings…" menu item, show one `NSMenuItem` per assigned slot, disabled (display only)
  - Format: `⌥1 → Safari`, `⌥2 → Terminal`, etc.
  - Unassigned slots are omitted
- **Implementation:** Rebuild `buildMenu()` in `StatusBarController` using `SettingsStore.assignments`; call `buildMenu()` again whenever `store.assignments` changes (use `Combine` subscription)

---

### Tier 2 — Medium Complexity

#### 4. Custom Modifier Key
- **UI:** Segmented control in Settings — `Option` / `Control`
- **Storage:** `UserDefaults` key `modifierKey` (`String`, values `"option"` / `"control"`)
- **Warning:** Display a yellow banner when `Control` is selected:
  > "Control+1–9 may conflict with macOS system shortcuts (e.g. Mission Control spaces)"
- **Implementation:** `HotkeyManager` reads modifier at `start()` time and builds `optionOnly` / `controlOnly` mask accordingly

#### 5. Window Cycling
- **Behavior:** If the assigned app is already the frontmost app, pressing its slot again cycles through its open windows (like Exposé cycling)
- **Implementation:** In `AppSwitcherService.activate()`, check `NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID`. If true, use `AXUIElement` to find the next non-minimized window and raise it (`AXUIElementSetAttributeValue(window, kAXMainAttribute, true)`)
- **Edge case:** Single-window apps → pressing again does nothing (cycle wraps to same window)

#### 6. Running Indicator
- **Already built:** `AppPickerRow` can detect running state
- **Implementation:** In `AppPickerRow`, observe `NSWorkspace.shared.runningApplications` via a timer or `NSWorkspace.didActivateApplicationNotification`. Show a green circle (SF Symbol `circle.fill`, color `.green`) next to the app name in the picker row when `NSRunningApplication.runningApplications(withBundleIdentifier: app.id).isEmpty == false`
- **Performance note:** Poll at most every 5 seconds; avoid per-keystroke lookups

---

### Tier 3 — Future

#### 7. In-App Auto-Update via Sparkle
- **Framework:** [Sparkle 2](https://sparkle-project.org) — add via Swift Package Manager
- **Flow:** On launch, `SPUStandardUpdaterController` checks `appcast.xml` hosted on GitHub Pages or in the GitHub Release assets
- **UI:** "Check for Updates…" menu item in the status bar menu
- **Appcast:** A minimal XML file listing release versions, download URLs, SHA256, and minimum OS version
- **Note:** Requires a signed build; sparkle signatures (`EdDSA`) are generated with `generate_appcast` tool

#### 8. JSON Config Export/Import
- **Export:** Serialize `SettingsStore.assignments` (`[Int: String]`) to JSON, write to user-chosen file via `NSSavePanel`
- **Import:** Read JSON via `NSOpenPanel`, validate slot keys (1–9) and bundle IDs, merge into `SettingsStore`
- **Use case:** Sync slot assignments between multiple Macs, or share a configuration with another user
- **UI:** Two buttons in Settings footer — "Export Config…" and "Import Config…"

---

## Distribution

See `DISTRIBUTION.md` for full setup instructions.

### Architecture Overview

```
Developer machine
    │ git tag v1.0.0 && git push --tags
    ▼
GitHub Actions (CI/CD)
    │ xcodebuild archive
    │ codesign --deep (Developer ID cert from Secrets)
    │ xcrun notarytool submit (Apple credentials from Secrets)
    │ xcrun stapler staple
    │ hdiutil create → Flit-1.0.0.dmg
    │ shasum -a 256 → sha256
    │ gh release create v1.0.0 Flit-1.0.0.dmg
    │ Update Cask formula sha256 + version
    │ Push to homebrew-flit tap repo
    ▼
User
    brew tap alimuratkuslu/flit
    brew install --cask flit
```

### Key Files

| File | Purpose |
|---|---|
| `ExportOptions.plist` | Required by `xcodebuild -exportArchive`; sets method to `developer-id` |
| `Makefile` | Local build/archive/dmg targets for developer workflow |
| `.github/workflows/release.yml` | CI/CD: triggered on `git tag v*`; builds, signs, notarizes, releases |
| `homebrew-flit/Casks/flit.rb` | Homebrew Cask formula for `brew install --cask flit` |
| `DISTRIBUTION.md` | Full setup guide for both signed and unsigned distribution paths |
