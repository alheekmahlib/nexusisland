import Foundation
import Security

/// Thin wrapper around the macOS Keychain Services API for storing secret
/// values (OAuth tokens, API keys, API secrets) keyed by service + account.
///
/// Secrets must NOT live in `UserDefaults` — its plist is world-readable on
/// disk (no app-sandbox containerization in this build). Use this helper for
/// anything an integration would consider a credential.
///
/// Non-secret metadata (provider name, account id, display name) may still be
/// stored in `UserDefaults`.
enum KeychainStore {
    enum KeychainError: Error {
        case unhandled(OSStatus)
    }

    /// Save `data` (typically a JSON-encoded value) for the given
    /// `service` / `account` pair, overwriting any existing item.
    @discardableResult
    static func save(account: String, service: String, data: Data) -> Bool {
        // Remove any existing item first; SecItemAdd fails on duplicates.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Convenience for storing a UTF-8 string secret.
    @discardableResult
    static func save(string: String, account: String, service: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(account: account, service: service, data: data)
    }

    /// Load the raw `Data` for `service` / `account`, or `nil` if no such
    /// item exists.
    static func load(account: String, service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Convenience for loading a UTF-8 string secret.
    static func loadString(account: String, service: String) -> String? {
        guard let data = load(account: account, service: service) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Remove the item for `service` / `account`. Returns `true` if an item
    /// was deleted (or it was already gone).
    @discardableResult
    static func delete(account: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
