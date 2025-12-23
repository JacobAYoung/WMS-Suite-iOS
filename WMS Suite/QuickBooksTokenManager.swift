//
//  QuickBooksTokenManager.swift
//  WMS Suite
//
//  Handles QuickBooks OAuth flow and automatic token refresh
//

import Foundation
import Combine
import AuthenticationServices

class QuickBooksTokenManager: NSObject, ObservableObject {
    static let shared = QuickBooksTokenManager()
    
    // OAuth Configuration
    private let clientId: String
    private let clientSecret: String
    private let redirectURI = "https://harbordesksystems.com/quickbook"
    
    // Sandbox vs Production
    @Published var useSandbox: Bool = true
    
    private var authorizationEndpoint: String {
        useSandbox ?
            "https://appcenter.intuit.com/connect/oauth2" :
            "https://appcenter.intuit.com/connect/oauth2"
    }
    
    private var tokenEndpoint: String {
        useSandbox ?
            "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer" :
            "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
    }
    
    // Token Storage
    @Published var isAuthenticated: Bool = false
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiryDate: Date?
    private var realmId: String? // Company ID
    
    private override init() {
        // Load from UserDefaults or secure storage
        self.clientId = UserDefaults.standard.string(forKey: "quickbooksClientId") ?? ""
        self.clientSecret = UserDefaults.standard.string(forKey: "quickbooksClientSecret") ?? ""
        
        // Load saved tokens
        self.accessToken = UserDefaults.standard.string(forKey: "quickbooksAccessToken")
        self.refreshToken = UserDefaults.standard.string(forKey: "quickbooksRefreshToken")
        self.realmId = UserDefaults.standard.string(forKey: "quickbooksCompanyId")
        
        if let expiryTimestamp = UserDefaults.standard.object(forKey: "quickbooksTokenExpiry") as? Double {
            self.tokenExpiryDate = Date(timeIntervalSince1970: expiryTimestamp)
        }
        
        super.init()
        
        // Check if authenticated
        self.isAuthenticated = (accessToken != nil && refreshToken != nil && realmId != nil)
    }
    
    // MARK: - OAuth Flow
    
    /// Start OAuth flow - opens browser for user to login
    func startOAuthFlow(presentingViewController: UIViewController) {
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            print("❌ QuickBooks Client ID/Secret not configured")
            return
        }
        
        // Build authorization URL
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "com.intuit.quickbooks.accounting"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: UUID().uuidString) // CSRF protection
        ]
        
        guard let authURL = components.url else {
            print("❌ Failed to build authorization URL")
            return
        }
        
        // Open in-app browser
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "wmssuite") { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ OAuth error: \(error)")
                return
            }
            
            guard let callbackURL = callbackURL else {
                print("❌ No callback URL received")
                return
            }
            
            // Extract authorization code and realm ID from callback
            self.handleOAuthCallback(url: callbackURL)
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    /// Handle OAuth callback and exchange code for tokens
    private func handleOAuthCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("❌ Failed to parse callback URL")
            return
        }
        
        // Extract authorization code and realm ID
        guard let code = queryItems.first(where: { $0.name == "code" })?.value,
              let realmId = queryItems.first(where: { $0.name == "realmId" })?.value else {
            print("❌ Missing code or realmId in callback")
            return
        }
        
        print("✅ Received auth code and realm ID: \(realmId)")
        self.realmId = realmId
        
        // Exchange code for tokens
        Task {
            do {
                try await self.exchangeCodeForTokens(code: code)
            } catch {
                print("❌ Token exchange failed: \(error)")
            }
        }
    }
    
    /// Exchange authorization code for access & refresh tokens
    private func exchangeCodeForTokens(code: String) async throws {
        let url = URL(string: tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic Auth with client credentials
        let credentials = "\(clientId):\(clientSecret)"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Request body
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw QuickBooksAuthError.tokenExchangeFailed
        }
        
        // Parse tokens
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw QuickBooksAuthError.parseError
        }
        
        // Save tokens
        await MainActor.run {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            self.isAuthenticated = true
            
            // Persist to UserDefaults
            UserDefaults.standard.set(accessToken, forKey: "quickbooksAccessToken")
            UserDefaults.standard.set(refreshToken, forKey: "quickbooksRefreshToken")
            UserDefaults.standard.set(self.realmId, forKey: "quickbooksCompanyId")
            UserDefaults.standard.set(self.tokenExpiryDate?.timeIntervalSince1970, forKey: "quickbooksTokenExpiry")
            
            print("✅ QuickBooks authenticated successfully!")
        }
    }
    
    // MARK: - Token Refresh
    
    /// Check if token should be refreshed (within 10 minutes of expiry)
    func shouldRefreshToken() -> Bool {
        guard let expiryDate = tokenExpiryDate else { return true }
        let tenMinutesFromNow = Date().addingTimeInterval(10 * 60)
        return expiryDate < tenMinutesFromNow
    }
    
    /// Refresh access token using refresh token
    func refreshAccessToken() async throws -> (String, String) {
        guard let refreshToken = refreshToken else {
            throw QuickBooksAuthError.missingRefreshToken
        }
        
        let url = URL(string: tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic Auth
        let credentials = "\(clientId):\(clientSecret)"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Request body
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw QuickBooksAuthError.tokenRefreshFailed
        }
        
        // Parse new tokens
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String,
              let newRefreshToken = json["refresh_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw QuickBooksAuthError.parseError
        }
        
        // Update tokens
        await MainActor.run {
            self.accessToken = newAccessToken
            self.refreshToken = newRefreshToken
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            
            // Persist
            UserDefaults.standard.set(newAccessToken, forKey: "quickbooksAccessToken")
            UserDefaults.standard.set(newRefreshToken, forKey: "quickbooksRefreshToken")
            UserDefaults.standard.set(self.tokenExpiryDate?.timeIntervalSince1970, forKey: "quickbooksTokenExpiry")
            
            print("✅ QuickBooks token refreshed")
        }
        
        return (newAccessToken, newRefreshToken)
    }
    
    // MARK: - Logout
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpiryDate = nil
        realmId = nil
        isAuthenticated = false
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "quickbooksAccessToken")
        UserDefaults.standard.removeObject(forKey: "quickbooksRefreshToken")
        UserDefaults.standard.removeObject(forKey: "quickbooksCompanyId")
        UserDefaults.standard.removeObject(forKey: "quickbooksTokenExpiry")
        
        print("🔓 Logged out from QuickBooks")
    }
    
    // MARK: - Getters
    
    func getCurrentAccessToken() -> String? {
        return accessToken
    }
    
    func getCurrentRefreshToken() -> String? {
        return refreshToken
    }
    
    func getCompanyId() -> String? {
        return realmId
    }
    
    // MARK: - Configuration
    
    func setCredentials(clientId: String, clientSecret: String) {
        UserDefaults.standard.set(clientId, forKey: "quickbooksClientId")
        UserDefaults.standard.set(clientSecret, forKey: "quickbooksClientSecret")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension QuickBooksTokenManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Errors

enum QuickBooksAuthError: LocalizedError {
    case tokenExchangeFailed
    case tokenRefreshFailed
    case parseError
    case missingRefreshToken
    
    var errorDescription: String? {
        switch self {
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .parseError:
            return "Failed to parse QuickBooks response"
        case .missingRefreshToken:
            return "No refresh token available"
        }
    }
}
