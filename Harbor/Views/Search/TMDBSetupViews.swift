import SwiftUI

struct TMDBKeyPrompt: View {
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundColor(Theme.accent)
            Text("Unlock richer discovery")
                .font(.system(size: compact ? 19 : 24, weight: .bold, design: .serif))
            Text("Add a free TMDB API key for weekly trends, top-rated collections, genres and streaming-service charts. The key stays in the device Keychain and is never sent to analytics.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                TMDBSetupView()
            } label: {
                Label("Connect TMDB", systemImage: "arrow.right")
            }
            .buttonStyle(HarborPrimaryButtonStyle())
        }
        .padding(compact ? 16 : 20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }
}

struct TMDBSetupView: View {
    @ObservedObject private var settings = TMDBSettingsStore.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HarborPageHeader(
                    title: "Connect TMDB",
                    eyebrow: "Metadata",
                    subtitle: "Unlock weekly trends and curated discovery"
                )

                privacyNotice
                apiKeyField
                actionButtons

                if settings.hasAPIKey {
                    Button("Remove saved TMDB key", role: .destructive) {
                        settings.removeAPIKey()
                        draft = ""
                    }
                    .font(.subheadline)
                }
            }
            .frame(maxWidth: 660, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("TMDB")
        .harborNavigationChrome()
        .onAppear { draft = settings.apiKey }
    }

    private var privacyNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your key stays on this device", systemImage: "lock.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.accent)
            Text("Harbor stores the key in Keychain. It is used only for requests to api.themoviedb.org and is never included in analytics or crash reports.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TMDB v3 API key")
                .font(.caption.weight(.bold))
                .foregroundColor(Theme.textSecondary)
            SecureField("Paste API key", text: $draft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.border, lineWidth: 1))
            if let error = settings.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                guard let url = URL(string: "https://www.themoviedb.org/settings/api") else { return }
                openURL(url)
            } label: {
                Label("Get a free key", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(HarborSecondaryButtonStyle())

            Button {
                Task { await verifyAndSave() }
            } label: {
                if settings.validationState == .checking {
                    ProgressView().tint(.black)
                } else {
                    Label("Verify & Save", systemImage: "checkmark")
                }
            }
            .buttonStyle(HarborPrimaryButtonStyle())
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || settings.validationState == .checking)
        }
    }

    private func verifyAndSave() async {
        guard await settings.verifyAndSave(draft) else { return }
        await TMDBCatalogStore.shared.loadDiscovery(
            apiKey: settings.apiKey,
            region: UserDefaults.standard.string(forKey: "harbor.region") ?? "US",
            force: true
        )
        dismiss()
    }
}
