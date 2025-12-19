//
//  ShopifyPermissionsChecker.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
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
        // Map scopes to test queries
        let testQuery: String
        
        switch scope {
        case "read_products", "read_inventory":
            testQuery = """
            {
                products(first: 1) {
                    edges {
                        node {
                            id
                        }
                    }
                }
            }
            """
        case "write_products", "write_inventory":
            // For write permissions, we check if read works (write implies read)
            return await testPermission("read_products")
            
        case "read_orders":
            testQuery = """
            {
                orders(first: 1) {
                    edges {
                        node {
                            id
                        }
                    }
                }
            }
            """
        default:
            return false
        }
        
        do {
            let url = URL(string: "https://\(storeUrl)/admin/api/2025-01/graphql.json")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(accessToken, forHTTPHeaderField: "X-Shopify-Access-Token")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["query": testQuery], options: [])
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            // If we get 200, permission is enabled
            if httpResponse.statusCode == 200 {
                // Check for errors in GraphQL response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errors = json["errors"] as? [[String: Any]] {
                    // Check if error is permission-related
                    for error in errors {
                        if let message = error["message"] as? String,
                           message.contains("access") || message.contains("permission") {
                            return false
                        }
                    }
                    return true
                }
                return true
            }
            
            return false
        } catch {
            print("Permission test failed for \(scope): \(error)")
            return false
        }
    }
}
