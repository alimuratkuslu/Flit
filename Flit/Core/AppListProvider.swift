import AppKit
import Combine

struct AppInfo: Identifiable, Hashable {
    let id: String       // bundle identifier, e.g. "com.apple.Safari"
    let name: String     // display name
    let icon: NSImage
    let bundleURL: URL

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// @unchecked Sendable: refresh() dispatches work to a background queue internally;
// all Published property mutations are dispatched back to the main queue.
final class AppListProvider: ObservableObject, @unchecked Sendable {

    nonisolated(unsafe) static let shared = AppListProvider()
    private init() {}

    @Published private(set) var apps: [AppInfo] = []

    private let searchPaths: [URL] = [
        "/Applications",
        NSHomeDirectory() + "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        "/Applications/Utilities",
    ].map { URL(fileURLWithPath: $0) }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let found = self.scan().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { self.apps = found }
        }
    }

    // MARK: - Private

    private func scan() -> [AppInfo] {
        var result: [AppInfo] = []
        var seen = Set<String>()

        for base in searchPaths {
            let items = (try? FileManager.default.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )) ?? []

            for url in items where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      !seen.contains(bundleID)
                else { continue }

                let name: String = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.infoDictionary?["CFBundleName"] as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 16, height: 16)

                result.append(AppInfo(id: bundleID, name: name, icon: icon, bundleURL: url))
                seen.insert(bundleID)
            }
        }
        return result
    }
}
