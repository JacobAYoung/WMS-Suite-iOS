//
//  ShopifyService.swift (UPDATED FOR OAUTH)
//  WMS Suite
//
//  Updated to support OAuth authentication
//

import Foundation
import CoreData

class ShopifyService: ShopifyServiceProtocol {
    private var storeUrl: String
    private var accessToken: String
    
    init(storeUrl: String, accessToken: String) {
        self.storeUrl = storeUrl
        self.accessToken = accessToken
    }
    
    /// Convenience initializer that gets token from OAuth manager
    convenience init() {
        let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? ""
        let accessToken = ShopifyOAuthManager.shared.getAccessToken(for: storeUrl) ?? ""
        self.init(storeUrl: storeUrl, accessToken: accessToken)
    }
    
    func updateCredentials(storeUrl: String, accessToken: String) {
        self.storeUrl = storeUrl
        self.accessToken = accessToken
    }
    
    // MARK: - Authenticated Request Helper
    
    /// Make an authenticated request using stored OAuth token
    private func makeAuthenticatedRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var modifiedRequest = request
        
        // Try to get the latest token from OAuth manager
        if let latestToken = ShopifyOAuthManager.shared.getAccessToken(for: storeUrl), !latestToken.isEmpty {
            self.accessToken = latestToken
        }
        
        // Set the access token header
        modifiedRequest.setValue(accessToken, forHTTPHeaderField: "X-Shopify-Access-Token")
        modifiedRequest.timeoutInterval = 60
        
        do {
            let (data, response) = try await URLSession.shared.data(for: modifiedRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ShopifyError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to extract error message
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errors = errorJson["errors"] as? [String: Any] {
                    print("Shopify API Error: \(errors)")
                }
                throw ShopifyError.httpError(statusCode: httpResponse.statusCode)
            }
            
            return (data, httpResponse)
            
        } catch let error as ShopifyError {
            throw error
        } catch {
            print("❌ Shopify request error: \(error)")
            throw ShopifyError.invalidResponse
        }
    }
    
    // MARK: - Sync Inventory
    
    func syncInventory(localItems: [InventoryItem], repo: InventoryRepositoryProtocol, logMismatch: @escaping (String) -> Void) async throws {
        guard !accessToken.isEmpty && !storeUrl.isEmpty else {
            throw ShopifyError.missingCredentials
        }
        
        let url = URL(string: "https://\(storeUrl)/admin/api/2025-01/graphql.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let query = """
        {
            products(first: 100) {
                edges {
                    node {
                        id
                        title
                        featuredImage {
                            url
                        }
                        variants(first: 10) {
                            edges {
                                node {
                                    id
                                    sku
                                    inventoryQuantity
                                }
                            }
                        }
                    }
                }
            }
        }
        """
        
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query], options: [])
        
        print("Syncing inventory from Shopify...")
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = result["data"] as? [String: Any],
              let productsDict = dataDict["products"] as? [String: Any],
              let edges = productsDict["edges"] as? [[String: Any]] else {
            print("Failed to parse Shopify response")
            throw ShopifyError.parseError
        }
        
        print("Found \(edges.count) products from Shopify")
        
        // Get fresh items from database to prevent duplicates
        let freshItems = try await repo.fetchAllItems()
        
        for edge in edges {
            guard let node = edge["node"] as? [String: Any],
                  let title = node["title"] as? String,
                  let productId = node["id"] as? String,
                  let variantsDict = node["variants"] as? [String: Any],
                  let variantEdges = variantsDict["edges"] as? [[String: Any]] else {
                continue
            }
            
            // Extract image URL if available
            var imageUrl: String? = nil
            if let featuredImage = node["featuredImage"] as? [String: Any],
               let url = featuredImage["url"] as? String {
                imageUrl = url
            }
            
            for variantEdge in variantEdges {
                guard let variantNode = variantEdge["node"] as? [String: Any],
                      let sku = variantNode["sku"] as? String,
                      !sku.isEmpty,
                      let shopQty = variantNode["inventoryQuantity"] as? Int else {
                    continue
                }
                
                // Check if item exists in database
                if let localItem = freshItems.first(where: { $0.sku == sku }) {
                    // Update existing item
                    var needsUpdate = false
                    
                    if localItem.quantity != Int32(shopQty) {
                        logMismatch("Mismatch for \(sku): Local \(localItem.quantity), Shopify \(shopQty)")
                        localItem.quantity = Int32(shopQty)
                        needsUpdate = true
                    }
                    
                    if localItem.shopifyProductId != productId {
                        localItem.shopifyProductId = productId
                        needsUpdate = true
                    }
                    
                    if localItem.imageUrl != imageUrl {
                        localItem.imageUrl = imageUrl
                        needsUpdate = true
                    }
                    
                    if needsUpdate {
                        localItem.lastSyncedShopifyDate = Date()
                        try await repo.updateItem(localItem)
                        print("Updated item: \(sku)")
                    }
                    
                } else {
                    // Create new item from Shopify
                    let newItem = try await repo.createItem(
                        sku: sku,
                        name: title,
                        description: nil,
                        upc: nil,
                        webSKU: nil,
                        quantity: Int32(shopQty),
                        minStockLevel: 0,
                        imageUrl: imageUrl
                    )
                    
                    newItem.shopifyProductId = productId
                    newItem.lastSyncedShopifyDate = Date()
                    try await repo.updateItem(newItem)
                    
                    logMismatch("Added new item \(sku) from Shopify")
                    print("Created new item: \(sku)")
                }
            }
        }
        
        print("Shopify sync completed")
    }
    
    // MARK: - Fetch Recent Sales
    
    func fetchRecentSales(for item: InventoryItem) async throws -> [SalesHistoryDisplay] {
        var allSales: [SalesHistoryDisplay] = []
        
        // 1. Fetch local sales from Core Data
        let context = PersistenceController.shared.container.viewContext
        let localSales = try await context.perform {
            let sales = Sale.fetchSales(for: item, context: context)
            
            return sales.compactMap { sale -> SalesHistoryDisplay? in
                guard let lineItems = sale.lineItems as? Set<SaleLineItem>,
                      let lineItem = lineItems.first(where: { $0.item == item }) else {
                    return nil
                }
                
                return SalesHistoryDisplay(
                    saleDate: sale.saleDate,
                    orderNumber: sale.orderNumber,
                    quantity: lineItem.quantity
                )
            }
        }
        
        allSales.append(contentsOf: localSales)
        
        // 2. Fetch from Shopify (if credentials are configured)
        if !accessToken.isEmpty && !storeUrl.isEmpty {
            do {
                let shopifySales = try await fetchShopifySales(for: item, context: context)
                allSales.append(contentsOf: shopifySales)
            } catch {
                print("Shopify sales fetch failed: \(error.localizedDescription)")
            }
        }
        
        return allSales
    }

    private func fetchShopifySales(for item: InventoryItem, context: NSManagedObjectContext) async throws -> [SalesHistoryDisplay] {
        guard let sku = item.sku else {
            return []
        }
        
        let url = URL(string: "https://\(storeUrl)/admin/api/2025-01/graphql.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let query = """
        {
            orders(first: 100, query: "created_at:>-90d") {
                edges {
                    node {
                        id
                        name
                        createdAt
                        lineItems(first: 50) {
                            edges {
                                node {
                                    sku
                                    quantity
                                }
                            }
                        }
                    }
                }
            }
        }
        """
        
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query], options: [])
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = result["data"] as? [String: Any],
              let ordersDict = dataDict["orders"] as? [String: Any],
              let edges = ordersDict["edges"] as? [[String: Any]] else {
            throw ShopifyError.parseError
        }
        
        var salesHistory: [SalesHistoryDisplay] = []
        
        for edge in edges {
            guard let node = edge["node"] as? [String: Any],
                  let orderName = node["name"] as? String,
                  let createdAtString = node["createdAt"] as? String,
                  let lineItemsDict = node["lineItems"] as? [String: Any],
                  let lineItemEdges = lineItemsDict["edges"] as? [[String: Any]] else {
                continue
            }
            
            let dateFormatter = ISO8601DateFormatter()
            let saleDate = dateFormatter.date(from: createdAtString) ?? Date()
            
            for lineItemEdge in lineItemEdges {
                guard let lineItemNode = lineItemEdge["node"] as? [String: Any],
                      let itemSku = lineItemNode["sku"] as? String,
                      let quantity = lineItemNode["quantity"] as? Int,
                      itemSku == sku else {
                    continue
                }
                
                salesHistory.append(SalesHistoryDisplay(
                    saleDate: saleDate,
                    orderNumber: orderName,
                    quantity: Int32(quantity)
                ))
            }
        }
        
        return salesHistory
    }
    
    // MARK: - Push Item
    
    func pushItem(_ item: InventoryItem) async throws -> String {
        guard !accessToken.isEmpty && !storeUrl.isEmpty else {
            throw ShopifyError.missingCredentials
        }
        
        // TODO: Implement actual Shopify product creation/update
        // For now, return a dummy ID
        return "gid://shopify/Product/\(Int.random(in: 1000000...9999999))"
    }
}
