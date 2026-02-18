import Foundation
import Combine

final class SettingsStore: ObservableObject {

    nonisolated(unsafe) static let shared = SettingsStore()
    private init() { loadAll() }

    @Published private(set) var assignments: [Int: String] = [:]
    private let keyPrefix = "flit_slot_"

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
