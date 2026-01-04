//
//  KeychainHelper.swift
//  WMS Suite
//
//  Secure storage for sensitive credentials using iOS Keychain
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    // MARK: - Save to Keychain
    
    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("❌ Failed to encode value for key: \(key)")
            return false
        }
        
        // Delete any existing item first
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Saved to Keychain: \(key)")
            return true
        } else {
            print("❌ Failed to save to Keychain: \(key), status: \(status)")
            return false
        }
    }
    
    // MARK: - Async Save (for background operations)
    
    @discardableResult
    func saveAsync(_ value: String, forKey key: String) async -> Bool {
        return await Task.detached(priority: .userInitiated) {
            self.save(value, forKey: key)
        }.value
    }
    
    // MARK: - Retrieve from Keychain
    
    func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                print("⚠️ Failed to retrieve from Keychain: \(key), status: \(status)")
            }
            return nil
        }
        
        return value
    }
    
    // MARK: - Async Retrieve (for background operations)
    
    func getAsync(forKey key: String) async -> String? {
        return await Task.detached(priority: .userInitiated) {
            self.get(forKey: key)
        }.value
    }
    
    // MARK: - Delete from Keychain
    
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        } else {
            print("⚠️ Failed to delete from Keychain: \(key), status: \(status)")
            return false
        }
    }
    
    // MARK: - Clear All (for logout)
    
    func clearAll() {
        let secItemClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        
        for secItemClass in secItemClasses {
            let query: [String: Any] = [kSecClass as String: secItemClass]
            SecItemDelete(query as CFDictionary)
        }
        
        print("🗑️ Cleared all Keychain items")
    }
}

// MARK: - QuickBooks-Specific Extensions

extension KeychainHelper {
    
    // QuickBooks Keychain Keys
    private enum QBKeys {
        static let clientId = "com.wmssuite.quickbooks.clientId"
        static let clientSecret = "com.wmssuite.quickbooks.clientSecret"
        static let accessToken = "com.wmssuite.quickbooks.accessToken"
        static let refreshToken = "com.wmssuite.quickbooks.refreshToken"
        static let realmId = "com.wmssuite.quickbooks.realmId"
        static let tokenExpiry = "com.wmssuite.quickbooks.tokenExpiry"
    }
    
    // MARK: - QuickBooks OAuth Credentials
    
    func saveQBClientId(_ clientId: String) {
        save(clientId, forKey: QBKeys.clientId)
    }
    
    func getQBClientId() -> String? {
        return get(forKey: QBKeys.clientId)
    }
    
    func saveQBClientSecret(_ clientSecret: String) {
        save(clientSecret, forKey: QBKeys.clientSecret)
    }
    
    func getQBClientSecret() -> String? {
        return get(forKey: QBKeys.clientSecret)
    }
    
    // MARK: - QuickBooks Tokens
    
    func saveQBAccessToken(_ token: String) {
        save(token, forKey: QBKeys.accessToken)
    }
    
    func getQBAccessToken() -> String? {
        return get(forKey: QBKeys.accessToken)
    }
    
    func saveQBRefreshToken(_ token: String) {
        save(token, forKey: QBKeys.refreshToken)
    }
    
    func getQBRefreshToken() -> String? {
        return get(forKey: QBKeys.refreshToken)
    }
    
    func saveQBRealmId(_ realmId: String) {
        save(realmId, forKey: QBKeys.realmId)
    }
    
    func getQBRealmId() -> String? {
        return get(forKey: QBKeys.realmId)
    }
    
    func saveQBTokenExpiry(_ date: Date) {
        let timestamp = String(date.timeIntervalSince1970)
        save(timestamp, forKey: QBKeys.tokenExpiry)
    }
    
    func getQBTokenExpiry() -> Date? {
        guard let timestampString = get(forKey: QBKeys.tokenExpiry),
              let timestamp = Double(timestampString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    // MARK: - Clear QuickBooks Data
    
    func clearQBCredentials() {
        delete(forKey: QBKeys.clientId)
        delete(forKey: QBKeys.clientSecret)
        delete(forKey: QBKeys.accessToken)
        delete(forKey: QBKeys.refreshToken)
        delete(forKey: QBKeys.realmId)
        delete(forKey: QBKeys.tokenExpiry)
        print("🗑️ Cleared all QuickBooks credentials from Keychain")
    }
}
