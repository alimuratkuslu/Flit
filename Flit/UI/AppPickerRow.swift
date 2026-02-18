import SwiftUI

struct AppPickerRow: View {

    let slot: Int

    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var listProvider: AppListProvider

    @State private var selectedBundleID: String = ""

    var body: some View {
        HStack(spacing: 14) {
            // Slot badge — e.g. "⌥1"
            Text("⌥\(slot)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 32)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(5)

            // App picker
            Picker("", selection: $selectedBundleID) {
                Text("— None —")
                    .foregroundColor(.secondary)
                    .tag("")

                if listProvider.apps.isEmpty {
                    Text("Loading apps...")
                        .foregroundColor(.secondary)
                        .tag("loading")
                } else {
                    ForEach(listProvider.apps) { app in
                        HStack(spacing: 6) {
                            Image(nsImage: app.icon)
                            Text(app.name)
                        }
                        .tag(app.id)
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            // Use macOS 13-compatible onChange (one-parameter form)
            .onChange(of: selectedBundleID) { newValue in
                store.setAssignment(
                    bundleID: newValue.isEmpty ? nil : newValue,
                    forSlot: slot
                )
            }

            // Running indicator dot
            Circle()
                .fill(isRunning ? Color.green : Color.clear)
                .frame(width: 7, height: 7)
                .help(isRunning ? "App is running" : "App is not running")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .onAppear {
            selectedBundleID = store.assignment(forSlot: slot) ?? ""
        }
        // Keep local state in sync if another part of the app updates the store
        .onChange(of: store.assignments) { _ in
            let stored = store.assignment(forSlot: slot) ?? ""
            if stored != selectedBundleID {
                selectedBundleID = stored
            }
        }
    }

    // MARK: - Helpers

    private var isRunning: Bool {
        guard !selectedBundleID.isEmpty else { return false }
        return !NSRunningApplication
            .runningApplications(withBundleIdentifier: selectedBundleID)
            .isEmpty
    }
}
