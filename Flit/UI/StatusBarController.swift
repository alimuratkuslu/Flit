import AppKit
import Sparkle
import SwiftUI

@MainActor
final class StatusBarController {

    private let statusItem: NSStatusItem
    private var settingsWindowController: NSWindowController?

    private let store: SettingsStore
    private let listProvider: AppListProvider
    private let updater: SPUUpdater

    init(store: SettingsStore, listProvider: AppListProvider, updater: SPUUpdater) {
        self.store = store
        self.listProvider = listProvider
        self.updater = updater

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Custom swift silhouette — template rendering lets macOS invert for dark/light menu bar.
            let icon = NSImage(named: "StatusBarIcon")
            icon?.isTemplate = true
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
        }

        buildMenu()
    }

    // MARK: - Accessibility Permission Alert

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            Flit needs Accessibility access to intercept ⌥+Number shortcuts.

            Click "Open Settings", grant access in System Settings → Privacy & Security → Accessibility, then relaunch Flit.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Quit")
        alert.alertStyle = .warning

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
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

        let updateItem = NSMenuItem(
            title: "Check for Updates\u{2026}",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Flit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Updates

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }

    // MARK: - Settings Window

    @objc private func openSettings() {
        // Refresh the installed-app list each time the panel opens.
        listProvider.refresh()

        if settingsWindowController == nil {
            let rootView = SettingsView()
                .environmentObject(store)
                .environmentObject(listProvider)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 540),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "Flit"
            panel.titlebarAppearsTransparent = false
            panel.contentViewController = NSHostingController(rootView: rootView)
            panel.center()

            // CRITICAL: without this, the panel is deallocated on close
            // and the next open crashes.
            panel.isReleasedWhenClosed = false

            settingsWindowController = NSWindowController(window: panel)
        }

        settingsWindowController?.showWindow(nil)

        // LSUIElement apps need this to actually pull the panel in front.
        NSApp.activate(ignoringOtherApps: true)
    }
}
