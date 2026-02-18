import Cocoa

// MARK: - HotkeyManager

// @unchecked Sendable: the event tap callback runs on CFRunLoopGetMain() —
// i.e., the main thread — so all access to HotkeyManager is serialized.
final class HotkeyManager: @unchecked Sendable {

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let store: SettingsStore
    private let switcher: AppSwitcherService

    // Hardware key codes for the number row on ANSI/US keyboards.
    // These are physical scan codes — NOT ASCII values.
    // Note: 5 and 6 are intentionally non-sequential (23, 22).
    //       7 and 9 are also non-sequential (26, 25).
    static let keyCodeToSlot: [CGKeyCode: Int] = [
        18: 1,   // 1
        19: 2,   // 2
        20: 3,   // 3
        21: 4,   // 4
        23: 5,   // 5
        22: 6,   // 6
        26: 7,   // 7
        28: 8,   // 8
        25: 9,   // 9
    ]

    init(store: SettingsStore, switcher: AppSwitcherService) {
        self.store = store
        self.switcher = switcher
    }

    // MARK: - Lifecycle

    func start() {
        guard eventTap == nil else { return }

        // passUnretained is safe here: AppDelegate holds HotkeyManager strongly
        // for the entire app lifetime, so self won't be deallocated.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,           // active tap — can consume events
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,  // C-compatible free function below
            userInfo: selfPtr
        ) else {
            print("[HotkeyManager] CGEvent.tapCreate failed — Accessibility permission missing?")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[HotkeyManager] Started — listening for ⌥+1 through ⌥+9")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        print("[HotkeyManager] Stopped")
    }

    // MARK: - Internal

    func activateSlot(_ slot: Int) {
        guard let bundleID = store.assignment(forSlot: slot) else {
            print("[HotkeyManager] Slot \(slot) has no assignment")
            return
        }
        print("[HotkeyManager] ⌥+\(slot) → activating \(bundleID)")
        switcher.activate(bundleID: bundleID)
    }

    func reEnableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

// MARK: - CGEventTap Callback
//
// MUST be a C-compatible free function. Swift closures with captures
// cannot be used as CFunctionPointers. We recover `self` from userInfo.

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    guard let ptr = userInfo else {
        return Unmanaged.passRetained(event)
    }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()

    // macOS may disable the event tap after sleep or screen lock.
    // We must re-enable it when we receive this notification.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        manager.reEnableTap()
        return nil
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let flags = event.flags
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

    // Accept only pure Option+N: Option held, nothing else.
    let isOptionOnly = flags.contains(.maskAlternate)
                    && !flags.contains(.maskCommand)
                    && !flags.contains(.maskControl)
                    && !flags.contains(.maskShift)

    guard isOptionOnly, let slot = HotkeyManager.keyCodeToSlot[keyCode] else {
        return Unmanaged.passRetained(event)   // not our shortcut — pass through
    }

    // Switch to main thread before touching AppKit / our state.
    DispatchQueue.main.async {
        manager.activateSlot(slot)
    }

    // Return nil to consume this event — it won't reach any other app.
    return nil
}
