import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = SettingsStore.shared
        let listProvider = AppListProvider.shared
        let switcher = AppSwitcherService.shared

        statusBarController = StatusBarController(store: store, listProvider: listProvider)

        if !AXIsProcessTrusted() {
            statusBarController.showPermissionAlert()
            // showPermissionAlert calls NSApp.terminate — execution stops here
        } else {
            hotkeyManager = HotkeyManager(store: store, switcher: switcher)
            hotkeyManager.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
    }
}
