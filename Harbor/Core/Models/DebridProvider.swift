import Foundation

enum DebridProvider: String, CaseIterable, Identifiable {
    case realDebrid = "realdebrid"
    case allDebrid = "alldebrid"
    case premiumize = "premiumize"
    case debridLink = "debridlink"
    case torbox = "torbox"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .realDebrid: return "Real-Debrid"
        case .allDebrid: return "AllDebrid"
        case .premiumize: return "Premiumize"
        case .debridLink: return "Debrid-Link"
        case .torbox: return "TorBox"
        }
    }

    var queryName: String { rawValue }

    private var keychainAccount: String { "debrid.\(rawValue)" }

    static func loadKey(_ provider: DebridProvider) -> String? {
        Keychain.string(for: "debrid.\(provider.rawValue)")
    }

    func saveKey(_ value: String) {
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            Keychain.delete(account: keychainAccount)
        } else {
            Keychain.set(value, for: keychainAccount)
        }
    }

    func loadExisting() -> String {
        Self.loadKey(self) ?? ""
    }
}
