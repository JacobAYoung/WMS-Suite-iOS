//
//  QuickBooksService.swift
//  WMS Suite
//
//  Complete QuickBooks Online implementation with AUTO TOKEN REFRESH
//

import Foundation

class QuickBooksService: QuickBooksServiceProtocol {
    private var companyId: String
    private var accessToken: String
    private var refreshToken: String
    
    // Account references (configured by user)
    private var incomeAccountId: String
    private var cogsAccountId: String
    private var assetAccountId: String
    
    // QBO API endpoint (production)
    private let baseURL = "https://quickbooks.api.intuit.com/v3/company"
    
    init(companyId: String, accessToken: String, refreshToken: String) {
        self.companyId = companyId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        
        // Load account IDs from UserDefaults
        self.incomeAccountId = UserDefaults.standard.string(forKey: "quickbooksIncomeAccountId") ?? ""
        self.cogsAccountId = UserDefaults.standard.string(forKey: "quickbooksCOGSAccountId") ?? ""
        self.assetAccountId = UserDefaults.standard.string(forKey: "quickbooksAssetAccountId") ?? ""
    }
    
    func updateCredentials(companyId: String, accessToken: String, refreshToken: String) {
        self.companyId = companyId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    
    // MARK: - AUTO-REFRESH AUTHENTICATED REQUEST
    
    /// Make an authenticated request with automatic token refresh on 401
    private func makeAuthenticatedRequest(_ request: URLRequest, maxRetries: Int = 1) async throws -> (Data, HTTPURLResponse) {
        var modifiedRequest = request
        
        // Check if we should preemptively refresh the token
        if QuickBooksTokenManager.shared.shouldRefreshToken() {
            print("⏰ QuickBooks token expiring soon, refreshing proactively...")
            do {
                let (newAccessToken, _) = try await QuickBooksTokenManager.shared.refreshAccessToken()
                self.accessToken = newAccessToken
            } catch {
                print("⚠️ Proactive token refresh failed: \(error)")
                // Continue with current token, will retry on 401
            }
        }
        
        modifiedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: modifiedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuickBooksError.invalidResponse
        }
        
        // Check for 401 Unauthorized (expired token)
        if httpResponse.statusCode == 401 && maxRetries > 0 {
            print("⚠️ QuickBooks token expired, refreshing...")
            
            do {
                // Refresh the token
                let (newAccessToken, _) = try await QuickBooksTokenManager.shared.refreshAccessToken()
                
                // Update our local token
                self.accessToken = newAccessToken
                
                // Retry the request with new token
                print("🔄 Retrying request with new token...")
                return try await makeAuthenticatedRequest(request, maxRetries: maxRetries - 1)
                
            } catch {
                print("❌ Token refresh failed: \(error)")
                throw error
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fault = errorJson["Fault"] as? [String: Any],
               let errors = fault["Error"] as? [[String: Any]],
               let message = errors.first?["Message"] as? String {
                print("QBO Error: \(message)")
            }
            throw QuickBooksError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return (data, httpResponse)
    }
    
    // MARK: - Push Item to QuickBooks
    
    func pushItem(_ item: InventoryItem) async throws -> String {
        guard !accessToken.isEmpty && !companyId.isEmpty else {
            throw QuickBooksError.missingCredentials
        }
        
        guard !incomeAccountId.isEmpty && !cogsAccountId.isEmpty && !assetAccountId.isEmpty else {
            throw QuickBooksError.missingAccountConfiguration
        }
        
        // Check if item already exists in QBO
        if let qbItemId = item.quickbooksItemId, !qbItemId.isEmpty {
            // Update existing item
            try await updateQBOItem(item, qboItemId: qbItemId)
            return qbItemId
        } else {
            // Create new item
            return try await createQBOItem(item)
        }
    }
    
    // MARK: - Create New Item in QBO
    
    private func createQBOItem(_ item: InventoryItem) async throws -> String {
        let url = URL(string: "\(baseURL)/\(companyId)/item")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Don't set Authorization here - makeAuthenticatedRequest does it
        
        let itemData: [String: Any] = [
            "Name": item.name ?? item.sku ?? "Unknown Item",
            "Sku": item.sku ?? "",
            "Description": item.itemDescription ?? "",
            "Type": "Inventory",
            "TrackQtyOnHand": true,
            "QtyOnHand": Int(item.quantity),
            "InvStartDate": ISO8601DateFormatter().string(from: Date()),
            "IncomeAccountRef": ["value": incomeAccountId],
            "ExpenseAccountRef": ["value": cogsAccountId],
            "AssetAccountRef": ["value": assetAccountId]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: itemData, options: [])
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let itemResponse = json["Item"] as? [String: Any],
              let itemId = itemResponse["Id"] as? String else {
            throw QuickBooksError.parseError
        }
        
        print("✅ Created QBO Item with ID: \(itemId)")
        return itemId
    }
    
    // MARK: - Update Existing Item in QBO
    
    private func updateQBOItem(_ item: InventoryItem, qboItemId: String) async throws {
        // First, fetch the current item to get SyncToken (required for updates)
        let currentItem = try await fetchQBOItem(itemId: qboItemId)
        
        guard let syncToken = currentItem["SyncToken"] as? String else {
            throw QuickBooksError.missingSyncToken
        }
        
        let url = URL(string: "\(baseURL)/\(companyId)/item")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Don't set Authorization here - makeAuthenticatedRequest does it
        
        let itemData: [String: Any] = [
            "Id": qboItemId,
            "SyncToken": syncToken,
            "Name": item.name ?? item.sku ?? "Unknown Item",
            "Sku": item.sku ?? "",
            "Description": item.itemDescription ?? "",
            "QtyOnHand": Int(item.quantity),
            "sparse": true // Only update provided fields
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: itemData, options: [])
        
        let (_, _) = try await makeAuthenticatedRequest(request)
        
        print("✅ Updated QBO Item: \(qboItemId)")
    }
    
    // MARK: - Fetch Item from QBO
    
    private func fetchQBOItem(itemId: String) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/\(companyId)/item/\(itemId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Don't set Authorization here - makeAuthenticatedRequest does it
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = json["Item"] as? [String: Any] else {
            throw QuickBooksError.parseError
        }
        
        return item
    }
    
    // MARK: - Sync Inventory from QBO
    
    func syncInventory() async throws -> [InventoryItem] {
        guard !accessToken.isEmpty && !companyId.isEmpty else {
            throw QuickBooksError.missingCredentials
        }
        
        // Query for all inventory items
        let query = "SELECT * FROM Item WHERE Type = 'Inventory'"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let url = URL(string: "\(baseURL)/\(companyId)/query?query=\(encodedQuery)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Don't set Authorization here - makeAuthenticatedRequest does it
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryResponse = json["QueryResponse"] as? [String: Any],
              let items = queryResponse["Item"] as? [[String: Any]] else {
            throw QuickBooksError.parseError
        }
        
        print("📦 Fetched \(items.count) items from QuickBooks Online")
        
        // TODO: Convert QBO items to InventoryItem objects and return
        // This would be similar to Shopify sync
        return []
    }
    
    // MARK: - Get Account References
    
    func fetchAccounts() async throws -> [QBAccount] {
        let query = "SELECT * FROM Account"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let url = URL(string: "\(baseURL)/\(companyId)/query?query=\(encodedQuery)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Don't set Authorization here - makeAuthenticatedRequest does it
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryResponse = json["QueryResponse"] as? [String: Any],
              let accounts = queryResponse["Account"] as? [[String: Any]] else {
            return []
        }
        
        return accounts.compactMap { accountDict in
            guard let id = accountDict["Id"] as? String,
                  let name = accountDict["Name"] as? String,
                  let accountType = accountDict["AccountType"] as? String else {
                return nil
            }
            return QBAccount(id: id, name: name, accountType: accountType)
        }
    }
}

// MARK: - Helper Models

struct QBAccount: Identifiable {
    let id: String
    let name: String
    let accountType: String
}

enum QuickBooksError: LocalizedError {
    case missingCredentials
    case missingAccountConfiguration
    case invalidResponse
    case httpError(statusCode: Int)
    case parseError
    case missingSyncToken
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "QuickBooks credentials are missing. Please configure in Settings."
        case .missingAccountConfiguration:
            return "QuickBooks accounts not configured. Please set up Income, COGS, and Asset accounts in Settings."
        case .invalidResponse:
            return "Invalid response from QuickBooks"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parseError:
            return "Failed to parse QuickBooks response"
        case .missingSyncToken:
            return "Missing SyncToken - item may have been modified"
        }
    }
}
