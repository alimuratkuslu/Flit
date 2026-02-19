import Cocoa
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = SettingsStore.shared
        let listProvider = AppListProvider.shared
        let switcher = AppSwitcherService.shared

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        statusBarController = StatusBarController(
            store: store,
            listProvider: listProvider,
            updater: updaterController.updater
        )

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
