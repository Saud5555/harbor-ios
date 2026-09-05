import SwiftUI

struct DebridSetupView: View {
    @ObservedObject private var manager = AddonManager.shared

    @State private var keys: [DebridProvider: String] = [:]
    @State private var isInstalling = false

    var body: some View {
        List {
            HarborPageHeader(
                title: "Streaming & Debrid",
                eyebrow: "Playback Services",
                subtitle: "Manage synced providers and optional Torrentio setup"
            )
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if let status = manager.statusMessage {
                Label(status, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
                    .listRowBackground(Theme.surface)
            }
            if let error = manager.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.subheadline)
                    .listRowBackground(Theme.surface)
            }

            syncedStreamingAddons
            syncedSubtitleAddons

            Section {
                ForEach(DebridProvider.allCases) { provider in
                    HStack {
                        Text(provider.displayName)
                            .font(.subheadline)
                            .frame(width: 96, alignment: .leading)
                        SecureField("API key", text: binding(provider))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.footnote)
                    }
                }
            } header: {
                Text("Optional Torrentio setup")
            } footer: {
                Text("Keys stay in this device's Keychain. Installing or updating Torrentio adds its configured transport URL to your Stremio account.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Button {
                    installTorrentio()
                } label: {
                    HStack {
                        if isInstalling {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(isInstalling ? "Updating…" : "Install / Update Torrentio")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isInstalling || manager.isLoading)
                .listRowBackground(Theme.accent)
                .foregroundColor(.white)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .tint(Theme.accent)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .harborNavigationChrome()
        .onAppear {
            loadKeys()
            AnalyticsService.shared.setCurrentScreen(.debridSetup, screenClass: "DebridSetupView")
        }
        .task {
            if let authKey = AuthStore.shared.authKey {
                await manager.reload(authKey: authKey)
            }
        }
    }

    private var syncedStreamingAddons: some View {
        Section {
            if manager.isLoading && manager.syncedStreamAddons.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                }
            } else if manager.syncedStreamAddons.isEmpty {
                Text("No configured streaming addon was found in your Stremio account.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                ForEach(manager.syncedStreamAddons) { addon in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(addon.displayName)
                                .font(.body.weight(.medium))
                            Text(manager.hasEmbeddedDebridConfiguration(addon)
                                 ? "Debrid configuration synced from Stremio"
                                 : "Streaming addon synced from Stremio")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
        } header: {
            Text("Stremio account")
        } footer: {
            if !manager.syncedStreamAddons.isEmpty {
                Text("Harbor uses these addons and their configured transport URLs automatically. You do not need to reinstall them or enter the debrid key again.")
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var syncedSubtitleAddons: some View {
        Section("Subtitle addons") {
            if manager.isLoading && manager.syncedSubtitleAddons.isEmpty {
                ProgressView().tint(Theme.accent)
                    .frame(maxWidth: .infinity)
            } else if manager.syncedSubtitleAddons.isEmpty {
                Text("No subtitle addon was found in your Stremio account.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                ForEach(manager.syncedSubtitleAddons) { addon in
                    Label(addon.displayName, systemImage: "captions.bubble.fill")
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func loadKeys() {
        for provider in DebridProvider.allCases {
            keys[provider] = provider.loadExisting()
        }
    }

    private func binding(_ provider: DebridProvider) -> Binding<String> {
        Binding(
            get: { keys[provider] ?? "" },
            set: {
                keys[provider] = $0
                provider.saveKey($0)
            }
        )
    }

    private func installTorrentio() {
        guard let authKey = AuthStore.shared.authKey else { return }
        isInstalling = true
        Task {
            defer { isInstalling = false }
            _ = await manager.installTorrentio(authKey: authKey)
        }
    }
}
