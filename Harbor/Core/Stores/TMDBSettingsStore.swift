import Combine
import Foundation

@MainActor
final class TMDBSettingsStore: ObservableObject {
    enum ValidationState: Equatable {
        case idle
        case checking
        case valid
        case invalid
    }

    static let shared = TMDBSettingsStore()
    private static let keychainAccount = "tmdb-api-key"

    @Published private(set) var apiKey: String
    @Published private(set) var validationState: ValidationState
    @Published private(set) var errorMessage: String?

    private let client: TMDBKeyValidating

    var hasAPIKey: Bool { !apiKey.isEmpty }

    init(client: TMDBKeyValidating = TMDBClient.shared) {
        self.client = client
        let stored = Keychain.string(for: Self.keychainAccount) ?? ""
        apiKey = stored
        validationState = stored.isEmpty ? .idle : .valid
    }

    @discardableResult
    func verifyAndSave(_ candidate: String) async -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationState = .invalid
            errorMessage = "Enter your TMDB v3 API key."
            return false
        }
        validationState = .checking
        errorMessage = nil
        do {
            try await client.validate(apiKey: trimmed)
            Keychain.set(trimmed, for: Self.keychainAccount)
            apiKey = trimmed
            validationState = .valid
            return true
        } catch {
            validationState = .invalid
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "TMDB validation failed."
            return false
        }
    }

    func removeAPIKey() {
        Keychain.delete(account: Self.keychainAccount)
        apiKey = ""
        validationState = .idle
        errorMessage = nil
        TMDBCatalogStore.shared.reset()
    }
}
