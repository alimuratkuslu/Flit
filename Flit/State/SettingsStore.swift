import Foundation
import Combine
import ServiceManagement

final class SettingsStore: ObservableObject {

    nonisolated(unsafe) static let shared = SettingsStore()
    private init() { loadAll() }

    @Published private(set) var assignments: [Int: String] = [:]
    private let keyPrefix = "flit_slot_"

    @Published var showHUD: Bool = UserDefaults.standard.object(forKey: "flit_showHUD") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showHUD, forKey: "flit_showHUD") }
    }

    /// Key code for the Focus Back shortcut (Option+key). Default 6 = Z on ANSI keyboard.
    var focusBackKeyCode: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "flit_focusBackKeyCode")
            return v == 0 ? 6 : v   // 0 means not set; default to Z
        }
        set { UserDefaults.standard.set(newValue, forKey: "flit_focusBackKeyCode") }
    }

    // MARK: - Launch at Login

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Flit: LaunchAtLogin error: \(error)")
        }
    }

    // MARK: - Public API

    func assignment(forSlot slot: Int) -> String? {
        assignments[slot]
    }

    func setAssignment(bundleID: String?, forSlot slot: Int) {
        if let id = bundleID, !id.isEmpty {
            assignments[slot] = id
            UserDefaults.standard.set(id, forKey: key(slot))
        } else {
            assignments.removeValue(forKey: slot)
            UserDefaults.standard.removeObject(forKey: key(slot))
        }
    }

    // MARK: - Private

    private func key(_ slot: Int) -> String { keyPrefix + "\(slot)" }

    private func loadAll() {
        var loaded: [Int: String] = [:]
        for slot in 1...9 {
            if let id = UserDefaults.standard.string(forKey: key(slot)) {
                loaded[slot] = id
            }
        }
        assignments = loaded
    }
}
