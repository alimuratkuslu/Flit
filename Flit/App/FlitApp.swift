import SwiftUI

@main
struct FlitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty Settings scene prevents the "no scenes provided" warning.
        // All windows are opened imperatively from StatusBarController.
        Settings { EmptyView() }
    }
}
