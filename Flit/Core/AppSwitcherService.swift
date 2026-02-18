import Cocoa

final class AppSwitcherService {

    nonisolated(unsafe) static let shared = AppSwitcherService()
    private init() {}

    /// Brings the running application with the given bundle ID to the foreground.
    /// Does nothing if the app is not currently running.
    func activate(bundleID: String) {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else { return }  // not running → do nothing

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
