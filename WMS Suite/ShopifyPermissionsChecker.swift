//
//  ShopifyPermissionsChecker.swift
//  WMS Suite
//
//  Updated: Added read_fulfillments permission for tracking
//

import SwiftUI
import Foundation

// MARK: - Models

struct ShopifyPermission: Identifiable {
    let id = UUID()
    let name: String
    let scope: String
    let description: String
    var isEnabled: Bool
}

// MARK: - Permission Checker

class ShopifyPermissionsChecker {
    private let storeUrl: String
    private let accessToken: String
    
    init(storeUrl: String, accessToken: String) {
        self.storeUrl = storeUrl
        self.accessToken = accessToken
    }
    
    /// Check all relevant permissions for inventory management
    func checkPermissions() async throws -> [ShopifyPermission] {
        var permissions: [ShopifyPermission] = [
            ShopifyPermission(
                name: "Read Products",
                scope: "read_products",
                description: "View product and inventory data",
                isEnabled: false
            ),
            ShopifyPermission(
                name: "Write Products",
                scope: "write_products",
                description: "Create and update products",
                isEnabled: false
            ),
            ShopifyPermission(
                name: "Read Inventory",
                scope: "read_inventory",
                description: "View inventory levels",
                isEnabled: false
            ),
            ShopifyPermission(
                name: "Write Inventory",
                scope: "write_inventory",
                description: "Update inventory quantities",
                isEnabled: false
            ),
            ShopifyPermission(
                name: "Read Orders",
                scope: "read_orders",
                description: "View order history",
                isEnabled: false
            ),
            // ✅ NEW: Added for fulfillment tracking
            ShopifyPermission(
                name: "Read Fulfillments",
                scope: "read_fulfillments",
                description: "View shipping and tracking information",
                isEnabled: false
            )
        ]
        
        // Test each permission by making a simple API call
        for i in 0..<permissions.count {
            permissions[i].isEnabled = await testPermission(permissions[i].scope)
        }
        
        return permissions
    }
    
    /// Test a specific permission by making an API call
    private func testPermission(_ scope: String) async -> Bool {
        // Get the actual scopes from Shopify's access_scopes endpoint
        // This is the CORRECT way to check permissions
        do {
            let url = URL(string: "https://\(storeUrl)/admin/oauth/access_scopes.json")!
            var request = URLRequest(url: url)
            request.setValue(accessToken, forHTTPHeaderField: "X-Shopify-Access-Token")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Failed to fetch access scopes, status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return false
            }
            
            // Parse the response to get actual scopes
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessScopes = json["access_scopes"] as? [[String: Any]] else {
                print("Failed to parse access scopes")
                return false
            }
            
            // Check if our scope is in the list
            for scopeDict in accessScopes {
                if let handle = scopeDict["handle"] as? String {
                    if handle == scope {
                        print("✅ Found scope: \(scope)")
                        return true
                    }
                }
            }
            
            print("❌ Scope not found: \(scope)")
            return false
            
        } catch {
            print("Error checking scope \(scope): \(error)")
            return false
        }
    }
}
