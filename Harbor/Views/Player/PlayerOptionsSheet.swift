import SwiftUI

@MainActor
struct PlayerOptionsSheet: View {
    @ObservedObject var player: VLCPlayerController
    @ObservedObject var subtitleEngine: SubtitleEngine

    @Environment(\.dismiss) private var dismiss
    @State private var subtitleScale: Double
    @State private var subtitleVerticalPosition: Double
    @State private var isSelectingSubtitle = false
    @State private var selectionError: String?
    @State private var embeddedLanguageCodeByTrackID: [Int32: String]

    private let speeds: [Float] = [
        0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0,
    ]

    init(player: VLCPlayerController, subtitleEngine: SubtitleEngine) {
        self.player = player
        self.subtitleEngine = subtitleEngine
        _subtitleScale = State(initialValue: player.subtitleScale)
        _subtitleVerticalPosition = State(initialValue: player.subtitleVerticalPosition)
        _embeddedLanguageCodeByTrackID = State(
            initialValue: Self.resolveEmbeddedLanguageCodes(player.subtitleTracks)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                playbackSection
                    .listRowBackground(Theme.surface)
                audioSection
                    .listRowBackground(Theme.surface)
                subtitleSection
                    .listRowBackground(Theme.surface)
                subtitleTimingSection
                    .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .tint(Theme.accent)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .harborNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Playback Options")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: player.subtitleTracks) { tracks in
                embeddedLanguageCodeByTrackID = Self.resolveEmbeddedLanguageCodes(tracks)
            }
        }
    }

    private var playbackSection: some View {
        Section("Playback speed") {
            Picker("Speed", selection: Binding(
                get: { player.rate },
                set: { player.setRate($0) }
            )) {
                ForEach(speeds, id: \.self) { speed in
                    Text(String(format: "%.2fx", speed)).tag(speed)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var audioSection: some View {
        Section("Audio track") {
            if player.audioTracks.isEmpty {
                Text("No selectable embedded audio tracks detected yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(player.audioTracks) { track in
                    Button {
                        player.selectAudioTrack(track)
                    } label: {
                        optionLabel(track.name, selected: player.selectedAudioTrackId == track.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var subtitleSection: some View {
        Section("Subtitle language") {
            Button {
                player.disableSubtitles()
                selectionError = nil
            } label: {
                optionLabel("Off", selected: player.selectedSubtitleTrackId == -1
                    && player.selectedExternalSubtitleLabel == nil)
            }

            if subtitleEngine.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading installed subtitle addons")
                        .foregroundColor(.secondary)
                }
            }

            ForEach(languageCodes, id: \.self) { code in
                Menu {
                    Button("Automatic · embedded first") {
                        selectPreferredSource(for: code)
                    }

                    ForEach(embeddedTracks(for: code)) { track in
                        Button("Embedded · \(track.name)") {
                            player.selectEmbeddedSubtitle(track)
                            selectionError = nil
                        }
                    }

                    ForEach(subtitleEngine.options(for: code)) { subtitle in
                        Button("\(subtitle.addonName) · \(subtitle.displayName)") {
                            selectExternal(subtitle)
                        }
                    }
                } label: {
                    HStack {
                        Text(SubtitleLanguages.displayName(for: code))
                        Spacer()
                        Text(sourceSummary(for: code))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let selected = player.selectedExternalSubtitleLabel {
                Label(selected, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if isSelectingSubtitle {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Preparing subtitle")
                }
            }

            if let error = selectionError ?? player.subtitleError ?? subtitleEngine.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundColor(.orange)
            } else if !subtitleEngine.isLoading, subtitleEngine.addonNames.isEmpty,
                      externalLanguageCodes.isEmpty {
                Text("No installed subtitle addons support this title.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var subtitleTimingSection: some View {
        Section("Subtitle appearance") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Delay")
                    Spacer()
                    Text(String(format: "%+.2f s", player.subtitleDelay))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: Binding(
                    get: { player.subtitleDelay },
                    set: { player.setSubtitleDelay($0) }
                ), in: -10...10, step: 0.25)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(subtitleScale))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $subtitleScale, in: 50...200, step: 5)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Vertical position")
                    Spacer()
                    Text("\(Int(subtitleVerticalPosition)) px higher")
                        .foregroundColor(.secondary)
                }
                Slider(value: $subtitleVerticalPosition, in: 0...300, step: 10)
            }

            Button("Apply size and position") {
                player.applySubtitleAppearance(
                    scale: subtitleScale,
                    verticalPosition: subtitleVerticalPosition
                )
            }

            Text("Applying size or position reloads the current stream at the same timestamp. Delay changes apply immediately.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var externalLanguageCodes: Set<String> {
        Set(subtitleEngine.subtitles.map(\.languageCode))
    }

    private var languageCodes: [String] {
        Set(embeddedLanguageCodeByTrackID.values).union(externalLanguageCodes).sorted {
            SubtitleLanguages.displayName(for: $0)
                .localizedCaseInsensitiveCompare(SubtitleLanguages.displayName(for: $1)) == .orderedAscending
        }
    }

    private func embeddedTracks(for code: String) -> [PlayerMediaTrack] {
        player.subtitleTracks.filter {
            $0.id >= 0 && embeddedLanguageCodeByTrackID[$0.id] == code
        }
    }

    private static func resolveEmbeddedLanguageCodes(
        _ tracks: [PlayerMediaTrack]
    ) -> [Int32: String] {
        Dictionary(uniqueKeysWithValues: tracks.compactMap { track in
            guard track.id >= 0,
                  let code = SubtitleLanguages.code(forTrackName: track.name) else { return nil }
            return (track.id, code)
        })
    }

    private func sourceSummary(for code: String) -> String {
        let embeddedCount = embeddedTracks(for: code).count
        let addonResults = subtitleEngine.options(for: code)
        let addonCount = Set(addonResults.map(\.addonId)).count
        var parts: [String] = []
        if embeddedCount > 0 { parts.append("embedded") }
        if addonCount > 0 { parts.append("\(addonCount) addon\(addonCount == 1 ? "" : "s")") }
        return parts.joined(separator: " + ")
    }

    private func selectPreferredSource(for code: String) {
        if let embedded = embeddedTracks(for: code).first {
            player.selectEmbeddedSubtitle(embedded)
            selectionError = nil
        } else if let external = subtitleEngine.options(for: code).first {
            selectExternal(external)
        } else {
            selectionError = "No subtitle is available for this language."
        }
    }

    private func selectExternal(_ subtitle: AddonSubtitle) {
        isSelectingSubtitle = true
        selectionError = nil
        Task {
            do {
                let localURL = try await subtitleEngine.cachedFile(for: subtitle)
                guard !Task.isCancelled else { return }
                player.selectExternalSubtitle(
                    url: localURL,
                    label: "\(SubtitleLanguages.displayName(for: subtitle.languageCode)) · \(subtitle.addonName)"
                )
            } catch {
                selectionError = "Could not download this subtitle: \(error.localizedDescription)"
            }
            isSelectingSubtitle = false
        }
    }

    private func optionLabel(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
            }
        }
    }
}
