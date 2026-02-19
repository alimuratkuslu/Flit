import AppKit
import SwiftUI

@MainActor
final class QuickPickOverlayController {
    static let shared = QuickPickOverlayController()
    private init() {}

    private var panel: NSPanel?
    private var globalMonitor: Any?

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        guard !isVisible else { return }

        let overlayView = QuickPickOverlayView(onSelect: { [weak self] slot in
            self?.hide()
            if let bundleID = SettingsStore.shared.assignment(forSlot: slot) {
                AppSwitcherService.shared.activate(bundleID: bundleID)
            }
        }, onDismiss: { [weak self] in
            self?.hide()
        })

        let hosting = NSHostingView(rootView: overlayView)
        hosting.frame = NSRect(x: 0, y: 0, width: 340, height: 200)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        p.contentView = hosting
        p.alphaValue = 0

        // Center on main screen
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.midX - 170
            let y = sf.midY - 100
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.orderFront(nil)
        panel = p

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            p.animator().alphaValue = 1.0
        }

        // Global monitor: close on Escape. Because the panel is .nonactivatingPanel
        // it never becomes the key window, so a local monitor would never fire.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hide()
            }
        }
    }

    func hide() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            p.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            p.close()
            if self?.panel === p { self?.panel = nil }
        })
    }
}

private struct QuickPickOverlayView: View {
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void

    @State private var apps: [(slot: Int, name: String, icon: NSImage)] = []

    var body: some View {
        VStack(spacing: 10) {
            Text("Quick Switch")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            let columns = [GridItem(.fixed(90)), GridItem(.fixed(90)), GridItem(.fixed(90))]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(apps, id: \.slot) { item in
                    Button {
                        onSelect(item.slot)
                    } label: {
                        VStack(spacing: 4) {
                            Image(nsImage: item.icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text(item.name)
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            Text("⌥\(item.slot)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 80, height: 70)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { loadApps() }
    }

    private func loadApps() {
        let assignments = SettingsStore.shared.assignments
        let appList = AppListProvider.shared.apps
        apps = (1...9).compactMap { slot -> (slot: Int, name: String, icon: NSImage)? in
            guard let bundleID = assignments[slot] else { return nil }
            if let info = appList.first(where: { $0.id == bundleID }) {
                return (slot, info.name, info.icon)
            }
            // Fall back to running app info
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
               let name = running.localizedName {
                return (slot, name, running.icon ?? NSImage())
            }
            return nil
        }
    }
}
