import Cocoa

final class AppSwitcherService {

    nonisolated(unsafe) static let shared = AppSwitcherService()
    private init() {}

    /// Brings the running application with the given bundle ID to the foreground.
    /// If the app is already frontmost, cycles to its next visible window instead.
    /// Does nothing if the app is not currently running.
    func activate(bundleID: String) {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else { return }  // not running → do nothing

        // If the target app is already frontmost, cycle its windows and return early.
        // This check MUST come before unhide/deminiaturize to avoid incorrect side-effects.
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
            cycleWindows(for: app)
            return
        }

        // 1. Unhide if fully hidden
        if app.isHidden { app.unhide() }

        // 2. Deminiaturize any minimized windows via Accessibility API
        deminiaturizeWindows(for: app)

        // 3. Activate (switches spaces for fullscreen apps automatically)
        if #available(macOS 14.0, *) {
            app.activate()              // new API: always ignores other apps
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    /// Cycles focus to the next visible (non-minimized) window of an already-frontmost app.
    /// If the app has zero or one visible window, does nothing.
    private func cycleWindows(for app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let allWindows = windowsValue as? [AXUIElement]
        else { return }

        // Filter to only non-minimized (visible) windows.
        let visibleWindows = allWindows.filter { window in
            var minimizedValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
                  let isMinimized = minimizedValue as? Bool
            else {
                return true  // Cannot read attribute → assume visible
            }
            return !isMinimized
        }

        guard visibleWindows.count > 1 else { return }

        // Find the index of the current main window.
        let currentIndex = visibleWindows.firstIndex { window in
            var mainValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXMainAttribute as CFString, &mainValue) == .success,
                  let isMain = mainValue as? Bool
            else { return false }
            return isMain
        } ?? -1  // -1 wraps to index 0 on the next line

        let nextIndex = (currentIndex + 1) % visibleWindows.count
        let nextWindow = visibleWindows[nextIndex]

        AXUIElementSetAttributeValue(nextWindow, kAXMainAttribute as CFString, true as CFBoolean)
        AXUIElementPerformAction(nextWindow, kAXRaiseAction as CFString)
    }

    private func deminiaturizeWindows(for app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement]
        else { return }

        for window in windows {
            var minimizedValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
               (minimizedValue as? Bool) == true {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFBoolean)
            }
        }
    }
}
