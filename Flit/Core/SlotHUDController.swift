import AppKit
import SwiftUI

@MainActor
final class SlotHUDController {
    static let shared = SlotHUDController()
    private init() {}

    private var panel: NSPanel?
    private var dismissTask: DispatchWorkItem?

    func show(appName: String, appIcon: NSImage, slot: Int?) {
        DispatchQueue.main.async { [weak self] in
            self?.dismissTask?.cancel()
            self?._show(appName: appName, appIcon: appIcon, slot: slot)
        }
    }

    private func _show(appName: String, appIcon: NSImage, slot: Int?) {
        // Close existing panel instantly if re-triggered
        panel?.close()
        panel = nil

        let showIcon = SettingsStore.shared.showHUDIcon
        let panelWidth: CGFloat = showIcon ? 220 : 160

        let hudView = SlotHUDView(appName: appName, appIcon: appIcon, slot: slot, showIcon: showIcon)
        let hosting = NSHostingView(rootView: hudView)
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: 60)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 60),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        p.isMovableByWindowBackground = false
        p.contentView = hosting
        p.alphaValue = 0

        // Position: top-center of the screen that has the frontmost window
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.midX - panelWidth / 2
            let y = sf.maxY - 90
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.orderFront(nil)
        panel = p

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            p.animator().alphaValue = 1.0
        }

        let task = DispatchWorkItem { [weak self, weak p] in
            guard let p else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.close()
                if self?.panel === p { self?.panel = nil }
            })
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: task)
    }
}

private struct SlotHUDView: View {
    let appName: String
    let appIcon: NSImage
    let slot: Int?
    let showIcon: Bool

    var body: some View {
        HStack(spacing: 12) {
            if showIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let slot {
                    Text("⌥\(slot)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
