import Foundation
import Security

/// Which Dexcom Share server the account lives on. Italian accounts are on the
/// non-US server; getting this wrong looks exactly like a wrong password, so it is
/// surfaced in the UI rather than guessed.
enum DexcomRegion: String, CaseIterable, Identifiable {
    case outsideUS
    case unitedStates

    var id: String { rawValue }

    var host: String {
        switch self {
        case .outsideUS: return "shareous1.dexcom.com"
        case .unitedStates: return "share2.dexcom.com"
        }
    }

    var displayName: String {
        switch self {
        case .outsideUS: return "Europa e resto del mondo"
        case .unitedStates: return "Stati Uniti"
        }
    }
}

struct DexcomCredentials: Equatable {
    var username: String
    var password: String
    var region: DexcomRegion
}

/// The password lives in the Keychain, never in UserDefaults and never in a log.
/// `afterFirstUnlock` so a background refresh can still read it while the phone is
/// locked, which is the whole point of this app.
enum DexcomCredentialStore {

    private static let service = "com.paolocelestini.glicemia.dexcomshare"
    private static let usernameKey = "dexcom.username"
    private static let regionKey = "dexcom.region"

    static func save(_ credentials: DexcomCredentials) throws {
        UserDefaults.standard.set(credentials.username, forKey: usernameKey)
        UserDefaults.standard.set(credentials.region.rawValue, forKey: regionKey)

        let account = credentials.username
        let data = Data(credentials.password.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func load() -> DexcomCredentials? {
        guard
            let username = UserDefaults.standard.string(forKey: usernameKey),
            !username.isEmpty
        else { return nil }

        let region = DexcomRegion(rawValue: UserDefaults.standard.string(forKey: regionKey) ?? "")
            ?? .outsideUS

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data,
            let password = String(data: data, encoding: .utf8)
        else { return nil }

        return DexcomCredentials(username: username, password: password, region: region)
    }

    static func clear() {
        if let username = UserDefaults.standard.string(forKey: usernameKey) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: username,
            ]
            SecItemDelete(query as CFDictionary)
        }
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.removeObject(forKey: regionKey)
    }

    static var hasCredentials: Bool {
        load() != nil
    }
}
