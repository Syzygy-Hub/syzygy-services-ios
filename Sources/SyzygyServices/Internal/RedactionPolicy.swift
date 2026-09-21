// Internal only — not exported from the module
enum RedactionPolicy {
    private static let redactedKeys: Set<String> = [
        "email", "userid", "user_id", "uid", "traits", "token", "password", "secret"
    ]

    static func redact(key: String, value: String) -> String {
        redactedKeys.contains(key.lowercased()) ? "<redacted>" : value
    }

    static func redactMap(_ map: [String: String]) -> [String: String] {
        // Per-key decision: only redact sensitive keys
        return map.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = redactedKeys.contains(pair.key.lowercased()) ? "<redacted>" : pair.value
        }
    }

    static func redactProperties(_ props: [String: Any]) -> [String: Any] {
        props.reduce(into: [String: Any]()) { result, pair in
            if redactedKeys.contains(pair.key.lowercased()) {
                result[pair.key] = "<redacted>"
            } else {
                result[pair.key] = pair.value
            }
        }
    }
}
