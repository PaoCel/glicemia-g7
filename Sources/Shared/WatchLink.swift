import Foundation

/// Wire format shared by iPhone and Watch. Property-list safe types only:
/// `WCSession` application context and messages reject anything else.
enum WatchLink {
    static let schemaVersion = 1

    enum Key {
        static let schema = "v"
        static let mgdl = "g"
        static let trend = "t"
        static let timestamp = "ts"
        static let source = "src"
        static let error = "err"
        /// Monotonic counter so the Watch can ignore out-of-order deliveries.
        static let sequence = "seq"
    }

    enum MessageKind {
        static let key = "kind"
        /// Watch -> iPhone: "send me whatever you have right now".
        static let requestSnapshot = "requestSnapshot"
        /// iPhone -> Watch: the Dexcom account, so the Watch can fetch on its own.
        static let credentials = "credentials"
    }

    enum CredentialKey {
        static let username = "cu"
        static let password = "cp"
        static let region = "cr"
        /// Empty payload means the account was removed on the iPhone.
        static let cleared = "cx"
    }

    /// The account is handed to the Watch so it can reach Dexcom without waiting for
    /// the iPhone app to be awake. WatchConnectivity payloads are encrypted between the
    /// paired devices, and the password lands in the Watch keychain, not in a file.
    static func encodeCredentials(username: String, password: String, region: String) -> [String: Any] {
        [
            MessageKind.key: MessageKind.credentials,
            CredentialKey.username: username,
            CredentialKey.password: password,
            CredentialKey.region: region,
        ]
    }

    static func encodeClearedCredentials() -> [String: Any] {
        [MessageKind.key: MessageKind.credentials, CredentialKey.cleared: true]
    }

    static func encode(reading: GlucoseReading?, error: String?, sequence: Int) -> [String: Any] {
        var payload: [String: Any] = [
            Key.schema: schemaVersion,
            Key.sequence: sequence,
        ]
        if let reading = reading {
            payload[Key.mgdl] = reading.mgdl
            payload[Key.trend] = reading.trend.rawValue
            payload[Key.timestamp] = reading.date.timeIntervalSince1970
            payload[Key.source] = reading.source.rawValue
        }
        if let error = error {
            payload[Key.error] = error
        }
        return payload
    }

    struct Snapshot {
        let reading: GlucoseReading?
        let error: String?
        let sequence: Int
    }

    static func decode(_ payload: [String: Any]) -> Snapshot? {
        guard let version = payload[Key.schema] as? Int, version == schemaVersion else { return nil }
        let sequence = payload[Key.sequence] as? Int ?? 0
        let error = payload[Key.error] as? String

        guard
            let mgdl = payload[Key.mgdl] as? Int,
            let timestamp = payload[Key.timestamp] as? Double
        else {
            return Snapshot(reading: nil, error: error, sequence: sequence)
        }

        let trend = TrendDirection(rawValue: payload[Key.trend] as? String ?? "") ?? .unknown
        let source = ReadingOrigin(rawValue: payload[Key.source] as? String ?? "") ?? .mock
        let reading = GlucoseReading(
            mgdl: mgdl,
            trend: trend,
            date: Date(timeIntervalSince1970: timestamp),
            source: source
        )
        return Snapshot(reading: reading, error: error, sequence: sequence)
    }
}
