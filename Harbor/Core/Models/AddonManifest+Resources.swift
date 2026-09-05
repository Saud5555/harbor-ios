import Foundation

extension AddonManifest {
    /// Whether the manifest exposes a resource at all, independent of a title.
    func advertises(resource name: String) -> Bool {
        guard behaviorHints?.configurationRequired != true else { return false }
        return (resources ?? []).contains { $0.typeName == name }
    }

    /// Apply both manifest-wide and resource-specific constraints consistently.
    func supports(resource name: String, type: String, id: String) -> Bool {
        guard behaviorHints?.configurationRequired != true,
              Self.matches(type, allowed: types),
              Self.matchesPrefix(id, allowed: idPrefixes) else { return false }
        return (resources ?? []).contains { resource in
            switch resource {
            case .named(let resourceName):
                return resourceName == name
            case .detailed(let definition):
                return definition.name == name
                    && Self.matches(type, allowed: definition.types)
                    && Self.matchesPrefix(id, allowed: definition.idPrefixes)
            }
        }
    }

    private static func matches(_ value: String, allowed: [String]?) -> Bool {
        guard let allowed, !allowed.isEmpty else { return true }
        return allowed.contains(value)
    }

    private static func matchesPrefix(_ value: String, allowed: [String]?) -> Bool {
        guard let allowed, !allowed.isEmpty else { return true }
        return allowed.contains { value.hasPrefix($0) }
    }
}
