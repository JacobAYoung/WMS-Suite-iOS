//
//  QuickBooksTokenManager.swift
//  WMS Suite
//
//  Handles automatic token refresh for QuickBooks Online
//

import Foundation

class QuickBooksTokenManager {
    static let shared = QuickBooksTokenManager()
    
    private init() {}
    
    /// Refresh the access token using the refresh token
    func refreshAccessToken() async throws -> (accessToken: String, refreshToken: String) {
        let refreshToken = UserDefaults.standard.string(forKey: "quickbooksRefreshToken") ?? ""
        let clientId = UserDefaults.standard.string(forKey: "quickbooksClientId") ?? ""
        let clientSecret = UserDefaults.standard.string(forKey: "quickbooksClientSecret") ?? ""
        
        guard !refreshToken.isEmpty else {
            throw TokenError.missingRefreshToken
        }
        
        guard !clientId.isEmpty && !clientSecret.isEmpty else {
            throw TokenError.missingClientCredentials
        }
        
        // Intuit's token refresh endpoint
        let url = URL(string: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic authentication with client ID and secret
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Request body
        let bodyParams = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = bodyParams.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TokenError.refreshFailed(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String,
              let newRefreshToken = json["refresh_token"] as? String else {
            throw TokenError.parseError
        }
        
        // Store new tokens
        UserDefaults.standard.set(newAccessToken, forKey: "quickbooksAccessToken")
        UserDefaults.standard.set(newRefreshToken, forKey: "quickbooksRefreshToken")
        
        // Store timestamp for expiration tracking (tokens expire in 1 hour)
        let expirationDate = Date().addingTimeInterval(3600) // 1 hour from now
        UserDefaults.standard.set(expirationDate, forKey: "quickbooksTokenExpiration")
        
        print("✅ Successfully refreshed QuickBooks tokens")
        
        return (newAccessToken, newRefreshToken)
    }
    
    /// Check if token should be refreshed (within 5 minutes of expiration)
    func shouldRefreshToken() -> Bool {
        guard let expirationDate = UserDefaults.standard.object(forKey: "quickbooksTokenExpiration") as? Date else {
            return false
        }
        
        // Refresh if within 5 minutes of expiration
        let fiveMinutesFromNow = Date().addingTimeInterval(300)
        return fiveMinutesFromNow >= expirationDate
    }
}

enum TokenError: LocalizedError {
    case missingRefreshToken
    case missingClientCredentials
    case invalidResponse
    case refreshFailed(statusCode: Int)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .missingRefreshToken:
            return "No refresh token available. Please re-authenticate."
        case .missingClientCredentials:
            return "Client ID and Secret not configured"
        case .invalidResponse:
            return "Invalid response from token server"
        case .refreshFailed(let code):
            return "Token refresh failed with status: \(code)"
        case .parseError:
            return "Failed to parse token response"
        }
    }
}
