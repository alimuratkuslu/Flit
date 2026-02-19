import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var listProvider: AppListProvider

    @State private var isTrusted: Bool = AXIsProcessTrusted()
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Flit")
                        .font(.headline)
                    Text("Option+Number → instantly focus an app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // ── Permission banner ─────────────────────────────────────────
            if !isTrusted {
                PermissionBannerView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Divider()

            // ── Slot list ─────────────────────────────────────────────────
            if listProvider.apps.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning installed apps…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(1...9, id: \.self) { slot in
                            AppPickerRow(slot: slot)
                                .environmentObject(store)
                                .environmentObject(listProvider)

                            if slot < 9 {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
            }

            Divider()

            // ── Toggle options ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }
                ))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Toggle("Show HUD on Switch", isOn: $store.showHUD)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Toggle("Show App Icon in HUD", isOn: $store.showHUDIcon)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .disabled(!store.showHUD)

                Toggle("Launch App if Not Running", isOn: $store.launchIfNotRunning)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Divider()

            // ── Footer ────────────────────────────────────────────────────
            HStack {
                Text("⌥+Number shortcuts are active globally")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 580)
        .onAppear {
            isTrusted = AXIsProcessTrusted()
        }
    }
}
