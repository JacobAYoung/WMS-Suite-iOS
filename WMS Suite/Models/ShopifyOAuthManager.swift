//
//  ShopifyOAuthManager.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/23/25.
//

import Foundation
import Security

class ShopifyOAuthManager {
    static let shared = ShopifyOAuthManager()
    
    // OAuth Configuration
    private let clientId: String // You'll need to create a Shopify app to get this
    private let redirectUri = "wmssuite://shopify/callback"
    private let scopes = [
        "read_products",
        "write_products",
        "read_inventory",
        "write_inventory",
        "read_orders",
        "read_fulfillments"
    ]
    
    private init() {
        // Load client ID from UserDefaults or use a default
        self.clientId = UserDefaults.standard.string(forKey: "shopifyClientId") ?? ""
    }
    
    // MARK: - OAuth Flow
    
    /// Generate the authorization URL for OAuth flow
    func getAuthorizationURL(storeUrl: String) -> URL? {
        guard !clientId.isEmpty else {
            print("⚠️ Shopify Client ID not configured")
            return nil
        }
        
        // Clean store URL (remove https:// if present)
        let cleanStoreUrl = storeUrl
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Generate random state for CSRF protection
        let state = UUID().uuidString
        UserDefaults.standard.set(state, forKey: "shopifyOAuthState")
        
        // Build authorization URL
        let scopeString = scopes.joined(separator: ",")
        let urlString = "https://\(cleanStoreUrl)/admin/oauth/authorize?" +
            "client_id=\(clientId)&" +
            "scope=\(scopeString)&" +
            "redirect_uri=\(redirectUri)&" +
            "state=\(state)"
        
        return URL(string: urlString)
    }
    
    /// Exchange authorization code for access token
    func exchangeCodeForToken(code: String, storeUrl: String, state: String) async throws -> String {
        // Verify state to prevent CSRF attacks
        guard let savedState = UserDefaults.standard.string(forKey: "shopifyOAuthState"),
              savedState == state else {
            throw ShopifyOAuthError.stateMismatch
        }
        
        guard !clientId.isEmpty else {
            throw ShopifyOAuthError.missingClientId
        }
        
        // Clean store URL
        let cleanStoreUrl = storeUrl
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Prepare token exchange request
        let url = URL(string: "https://\(cleanStoreUrl)/admin/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": getClientSecret(), // For public apps, this might not be needed
            "code": code
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ShopifyOAuthError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error_description"] as? String {
                    print("Shopify OAuth Error: \(errorMessage)")
                }
                throw ShopifyOAuthError.tokenExchangeFailed(statusCode: httpResponse.statusCode)
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                throw ShopifyOAuthError.parseError
            }
            
            // Store the access token securely
            try saveAccessToken(accessToken, for: cleanStoreUrl)
            
            // Store store URL
            UserDefaults.standard.set(cleanStoreUrl, forKey: "shopifyStoreUrl")
            
            // Clear the state
            UserDefaults.standard.removeObject(forKey: "shopifyOAuthState")
            
            print("✅ Successfully obtained Shopify access token")
            
            return accessToken
            
        } catch let error as ShopifyOAuthError {
            throw error
        } catch {
            print("❌ Token exchange error: \(error)")
            throw ShopifyOAuthError.networkError(error)
        }
    }
    
    // MARK: - Token Storage (Keychain)
    
    /// Save access token to Keychain for security
    private func saveAccessToken(_ token: String, for storeUrl: String) throws {
        let service = "com.wmssuite.shopify"
        let account = storeUrl
        
        // Create keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw ShopifyOAuthError.keychainError(status: status)
        }
        
        // Also store in UserDefaults as fallback (less secure but more convenient)
        UserDefaults.standard.set(token, forKey: "shopifyAccessToken")
    }
    
    /// Retrieve access token from Keychain
    func getAccessToken(for storeUrl: String) -> String? {
        let service = "com.wmssuite.shopify"
        let account = storeUrl
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            // Fallback to UserDefaults
            return UserDefaults.standard.string(forKey: "shopifyAccessToken")
        }
        
        return token
    }
    
    /// Delete access token from Keychain
    func deleteAccessToken(for storeUrl: String) {
        let service = "com.wmssuite.shopify"
        let account = storeUrl
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
        
        // Also remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: "shopifyAccessToken")
    }
    
    // MARK: - Client Credentials
    
    func setClientCredentials(clientId: String, clientSecret: String) {
        UserDefaults.standard.set(clientId, forKey: "shopifyClientId")
        
        // Store client secret in Keychain
        let service = "com.wmssuite.shopify.credentials"
        let account = "clientSecret"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: clientSecret.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getClientSecret() -> String {
        let service = "com.wmssuite.shopify.credentials"
        let account = "clientSecret"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            return UserDefaults.standard.string(forKey: "shopifyClientSecret") ?? ""
        }
        
        return secret
    }
    
    // MARK: - Validation
    
    /// Check if we have valid credentials
    func hasValidCredentials() -> Bool {
        guard let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl"),
              !storeUrl.isEmpty else {
            return false
        }
        
        guard let token = getAccessToken(for: storeUrl),
              !token.isEmpty else {
            return false
        }
        
        return true
    }
    
    /// Revoke access token (disconnect from Shopify)
    func revokeAccess() {
        if let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl") {
            deleteAccessToken(for: storeUrl)
        }
        
        UserDefaults.standard.removeObject(forKey: "shopifyStoreUrl")
        UserDefaults.standard.removeObject(forKey: "shopifyOAuthState")
        
        print("✅ Shopify access revoked")
    }
}

// MARK: - Errors

enum ShopifyOAuthError: LocalizedError {
    case missingClientId
    case stateMismatch
    case invalidResponse
    case tokenExchangeFailed(statusCode: Int)
    case parseError
    case keychainError(status: OSStatus)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "Shopify Client ID not configured. Please set up OAuth credentials."
        case .stateMismatch:
            return "Invalid state parameter - possible security issue"
        case .invalidResponse:
            return "Invalid response from Shopify"
        case .tokenExchangeFailed(let code):
            return "Token exchange failed with status: \(code)"
        case .parseError:
            return "Failed to parse Shopify response"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
