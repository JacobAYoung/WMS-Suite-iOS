//
//  ShopifyService.swift (COMPLETE WITH TWO-WAY SYNC & PAGINATION)
//  WMS Suite
//
//  Complete implementation with:
//  - Product updates (push changes to Shopify)
//  - Pagination (handles 1000s of products/orders)
//  - Order import (brings Shopify orders into app)
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
                    print("❌ Shopify API Error: \(errors)")
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
    
    // MARK: - Sync Inventory (WITH PAGINATION)
    
    func syncInventory(localItems: [InventoryItem], repo: InventoryRepositoryProtocol, logMismatch: @escaping (String) -> Void) async throws {
        guard !accessToken.isEmpty && !storeUrl.isEmpty else {
            throw ShopifyError.missingCredentials
        }
        
        print("🔄 Starting paginated inventory sync from Shopify...")
        logMismatch("Starting product sync...")
        
        var allProducts: [[String: Any]] = []
        var hasNextPage = true
        var cursor: String? = nil
        var pageCount = 0
        
        // Fetch all products with pagination (50 per page)
        while hasNextPage {
            pageCount += 1
            print("📄 Fetching product page \(pageCount)...")
            logMismatch("Fetching page \(pageCount)...")
            
            do {
                let (products, nextCursor) = try await fetchProductsPage(cursor: cursor)
                allProducts.append(contentsOf: products)
                
                if let nextCursor = nextCursor {
                    cursor = nextCursor
                    hasNextPage = true
                } else {
                    hasNextPage = false
                }
                
                // Safety: prevent infinite loops
                if pageCount > 200 {
                    print("⚠️ Reached safety limit of 200 pages (10,000 products)")
                    logMismatch("⚠️ Safety limit reached - synced first 10,000 products")
                    break
                }
            } catch {
                print("❌ Error fetching page \(pageCount): \(error)")
                throw error
            }
        }
        
        print("✅ Fetched \(allProducts.count) products across \(pageCount) pages")
        logMismatch("Fetched \(allProducts.count) products from Shopify")
        
        // Get fresh items from database to prevent duplicates
        let freshItems = try await repo.fetchAllItems()
        
        // Process all products
        var createdCount = 0
        var updatedCount = 0
        
        for (index, productNode) in allProducts.enumerated() {
            do {
                let result = try await processProduct(productNode, freshItems: freshItems, repo: repo, logMismatch: logMismatch)
                if result.created {
                    createdCount += 1
                } else if result.updated {
                    updatedCount += 1
                }
                
                // Log progress every 50 items
                if (index + 1) % 50 == 0 {
                    logMismatch("Processed \(index + 1)/\(allProducts.count) products...")
                }
            } catch {
                print("❌ Error processing product: \(error)")
                // Continue processing other products
            }
        }
        
        logMismatch("✅ Created \(createdCount) new, updated \(updatedCount) existing products")
        print("✅ Shopify inventory sync completed")
    }
    
    /// Fetch a single page of products with pagination
    private func fetchProductsPage(cursor: String?) async throws -> (products: [[String: Any]], nextCursor: String?) {
        let url = URL(string: "https://\(storeUrl)/admin/api/2025-01/graphql.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let afterClause = cursor != nil ? ", after: \"\(cursor!)\"" : ""
        
        let query = """
        {
            products(first: 50\(afterClause)) {
                pageInfo {
                    hasNextPage
                    endCursor
                }
                edges {
                    cursor
                    node {
                        id
                        title
                        descriptionHtml
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
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = result["data"] as? [String: Any],
              let productsDict = dataDict["products"] as? [String: Any],
              let pageInfo = productsDict["pageInfo"] as? [String: Any],
              let edges = productsDict["edges"] as? [[String: Any]] else {
            throw ShopifyError.parseError
        }
        
        let products = edges.compactMap { $0["node"] as? [String: Any] }
        let hasNextPage = pageInfo["hasNextPage"] as? Bool ?? false
        let endCursor = hasNextPage ? (pageInfo["endCursor"] as? String) : nil
        
        return (products, endCursor)
    }
    
    /// Process a single product from Shopify
    private func processProduct(_ node: [String: Any], freshItems: [InventoryItem], repo: InventoryRepositoryProtocol, logMismatch: @escaping (String) -> Void) async throws -> (created: Bool, updated: Bool) {
        guard let title = node["title"] as? String,
              let productId = node["id"] as? String,
              let variantsDict = node["variants"] as? [String: Any],
              let variantEdges = variantsDict["edges"] as? [[String: Any]] else {
            return (false, false)
        }
        
        // Extract image URL if available
        var imageUrl: String? = nil
        if let featuredImage = node["featuredImage"] as? [String: Any],
           let url = featuredImage["url"] as? String {
            imageUrl = url
        }
        
        // Extract description
        let description = node["descriptionHtml"] as? String
        
        var itemCreated = false
        var itemUpdated = false
        
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
                
                if localItem.itemDescription != description {
                    localItem.itemDescription = description
                    needsUpdate = true
                }
                
                if needsUpdate {
                    localItem.lastSyncedShopifyDate = Date()
                    try await repo.updateItem(localItem)
                    itemUpdated = true
                }
                
            } else {
                // Create new item from Shopify
                let newItem = try await repo.createItem(
                    sku: sku,
                    name: title,
                    description: description,
                    upc: nil,
                    webSKU: nil,
                    quantity: Int32(shopQty),
                    minStockLevel: 0,
                    imageUrl: imageUrl
                )
                
                newItem.shopifyProductId = productId
                newItem.lastSyncedShopifyDate = Date()
                try await repo.updateItem(newItem)
                
                itemCreated = true
            }
        }
        
        return (itemCreated, itemUpdated)
    }
    
    // MARK: - Push Item to Shopify (✅ COMPLETE IMPLEMENTATION)
    
    func pushItem(_ item: InventoryItem) async throws -> String {
        guard !accessToken.isEmpty && !storeUrl.isEmpty else {
            throw ShopifyError.missingCredentials
        }
        
        // Check if item already exists in Shopify
        if let productId = item.shopifyProductId, !productId.isEmpty {
            // Update existing product
            try await updateShopifyProduct(item: item, productId: productId)
            return productId
        } else {
            // Create new product
            return try await createShopifyProduct(item: item)
        }
    }
    
    /// Create new product in Shopify
    private func createShopifyProduct(item: InventoryItem) async throws -> String {
        let url = URL(string: "https://\(storeUrl)/admin/api/2025-01/graphql.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let title = (item.name ?? item.sku ?? "Unknown Product").replacingOccurrences(of: "\"", with: "\\\"")
        let sku = item.sku ?? ""
        let description = (item.itemDescription ?? "").replacingOccurrences(of: "\"", with: "\\\"")
        
        let mutation = """
        mutation {
            productCreate(input: {
                title: "\(title)",
                descriptionHtml: "\(description)",
                variants: [{
                    sku: "\(sku)",
                    inventoryItem: {
                        tracked: true
                    }
                }]
            }) {
                product {
                    id
                }
                userErrors {
                    field
                    message
                }
            }
        }
        """
        
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": mutation], options: [])
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = result["data"] as? [String: Any],
              let productCreate = dataDict["productCreate"] as? [String: Any] else {
            throw ShopifyError.parseError
        }
        
        // Check for user errors
        if let userErrors = productCreate["userErrors"] as? [[String: Any]], !userErrors.isEmpty {
            let errorMessages = userErrors.compactMap { $0["message"] as? String }.joined(separator: ", ")
            print("❌ Shopify product creation errors: \(errorMessages)")
            throw ShopifyError.parseError
        }
        
        guard let product = productCreate["product"] as? [String: Any],
              let productId = product["id"] as? String else {
            throw ShopifyError.parseError
        }
        
        print("✅ Created product in Shopify: \(productId)")
        return productId
    }
    
    /// Update existing product in Shopify
    private func updateShopifyProduct(item: InventoryItem, productId: String) async throws {
        let url = URL(string: "https://\(storeUrl)/admin/api/2025-01/graphql.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let title = (item.name ?? item.sku ?? "Unknown Product").replacingOccurrences(of: "\"", with: "\\\"")
        let description = (item.itemDescription ?? "").replacingOccurrences(of: "\"", with: "\\\"")
        
        let mutation = """
        mutation {
            productUpdate(input: {
                id: "\(productId)",
                title: "\(title)",
                descriptionHtml: "\(description)"
            }) {
                product {
                    id
                }
                userErrors {
                    field
                    message
                }
            }
        }
        """
        
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": mutation], options: [])
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = result["data"] as? [String: Any],
              let productUpdate = dataDict["productUpdate"] as? [String: Any] else {
            throw ShopifyError.parseError
        }
        
        // Check for user errors
        if let userErrors = productUpdate["userErrors"] as? [[String: Any]], !userErrors.isEmpty {
            let errorMessages = userErrors.compactMap { $0["message"] as? String }.joined(separator: ", ")
            print("❌ Shopify product update errors: \(errorMessages)")
            throw ShopifyError.parseError
        }
        
        print("✅ Updated product in Shopify: \(productId)")
    }
    
    // MARK: - Sync Orders from Shopify (✅ WITH PAGINATION)
    
    /// Import orders from Shopify with pagination
    func syncOrders(context: NSManagedObjectContext, logMessage: @escaping (String) -> Void) async throws {
        guard !accessToken.isEmpty && !storeUrl.isEmpty else {
            throw ShopifyError.missingCredentials
        }
        
        print("🔄 Starting paginated order sync from Shopify...")
        logMessage("Starting order sync...")
        
        var allOrders: [[String: Any]] = []
        var hasNextPage = true
        var cursor: String? = nil
        var pageCount = 0
        
        // Fetch all orders with pagination (50 per page)
        while hasNextPage {
            pageCount += 1
            print("📄 Fetching order page \(pageCount)...")
            logMessage("Fetching page \(pageCount)...")
            
            do {
                let (orders, nextCursor) = try await fetchOrdersPage(cursor: cursor)
                allOrders.append(contentsOf: orders)
                
                if let nextCursor = nextCursor {
                    cursor = nextCursor
                    hasNextPage = true
                } else {
                    hasNextPage = false
                }
                
                // Safety: prevent infinite loops
                if pageCount > 200 {
                    print("⚠️ Reached safety limit of 200 pages (10,000 orders)")
                    logMessage("⚠️ Safety limit reached - synced first 10,000 orders")
                    break
                }
            } catch {
                print("❌ Error fetching order page \(pageCount): \(error)")
                throw error
            }
        }
        
        print("✅ Fetched \(allOrders.count) orders across \(pageCount) pages")
        logMessage("Fetched \(allOrders.count) orders from Shopify")
        
        // Process all orders
        var createdCount = 0
        var updatedCount = 0
        
        for (index, orderNode) in allOrders.enumerated() {
            do {
                let result = try await processOrder(orderNode, context: context)
                if result.created {
                    createdCount += 1
                } else if result.updated {
                    updatedCount += 1
                }
                
                // Log progress every 50 orders
                if (index + 1) % 50 == 0 {
                    logMessage("Processed \(index + 1)/\(allOrders.count) orders...")
                }
            } catch {
                print("❌ Error processing order: \(error)")
                // Continue processing other orders
            }
        }
        
        logMessage("✅ Created \(createdCount) new orders, updated \(updatedCount) existing")
        print("✅ Shopify order sync completed")
    }
    
    /// Fetch a single page of orders with pagination
    private func fetchOrdersPage(cursor: String?) async throws -> (orders: [[String: Any]], nextCursor: String?) {
        let url = URL(string: "https://\(storeUrl)/admin/api/2025-01/graphql.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let afterClause = cursor != nil ? ", after: \"\(cursor!)\"" : ""
        
        // Query for last 90 days of orders
        let query = """
        {
            orders(first: 50\(afterClause), query: "created_at:>-90d") {
                pageInfo {
                    hasNextPage
                    endCursor
                }
                edges {
                    cursor
                    node {
                        id
                        name
                        createdAt
                        totalPriceSet {
                            shopMoney {
                                amount
                            }
                        }
                        displayFulfillmentStatus
                        lineItems(first: 50) {
                            edges {
                                node {
                                    sku
                                    quantity
                                    originalUnitPriceSet {
                                        shopMoney {
                                            amount
                                        }
                                    }
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
              let pageInfo = ordersDict["pageInfo"] as? [String: Any],
              let edges = ordersDict["edges"] as? [[String: Any]] else {
            throw ShopifyError.parseError
        }
        
        let orders = edges.compactMap { $0["node"] as? [String: Any] }
        let hasNextPage = pageInfo["hasNextPage"] as? Bool ?? false
        let endCursor = hasNextPage ? (pageInfo["endCursor"] as? String) : nil
        
        return (orders, endCursor)
    }
    
    /// Process a single order from Shopify
    private func processOrder(_ node: [String: Any], context: NSManagedObjectContext) async throws -> (created: Bool, updated: Bool) {
        return try await context.perform {
            guard let orderNumber = node["name"] as? String,
                  let createdAtString = node["createdAt"] as? String,
                  let lineItemsDict = node["lineItems"] as? [String: Any],
                  let lineItemEdges = lineItemsDict["edges"] as? [[String: Any]] else {
                return (false, false)
            }
            
            // Check if order already exists
            let fetchRequest = NSFetchRequest<Sale>(entityName: "Sale")
            fetchRequest.predicate = NSPredicate(format: "orderNumber == %@ AND source == %@", orderNumber, "shopify")
            fetchRequest.fetchLimit = 1
            
            let existingSales = try context.fetch(fetchRequest)
            
            // Parse date
            let dateFormatter = ISO8601DateFormatter()
            let saleDate = dateFormatter.date(from: createdAtString) ?? Date()
            
            // Parse total amount
            var totalAmount: NSDecimalNumber = NSDecimalNumber.zero
            if let totalPriceSet = node["totalPriceSet"] as? [String: Any],
               let shopMoney = totalPriceSet["shopMoney"] as? [String: Any],
               let amountString = shopMoney["amount"] as? String {
                totalAmount = NSDecimalNumber(string: amountString)
            }
            
            // Parse fulfillment status
            let fulfillmentStatusString = node["displayFulfillmentStatus"] as? String ?? "UNFULFILLED"
            let fulfillmentStatus = self.mapShopifyFulfillmentStatus(fulfillmentStatusString)
            
            let sale: Sale
            let isNew: Bool
            
            if let existingSale = existingSales.first {
                // Update existing
                sale = existingSale
                isNew = false
                
                // Update properties
                sale.totalAmount = totalAmount
                sale.fulfillmentStatus = fulfillmentStatus
            } else {
                // Create new
                sale = Sale(context: context)
                sale.id = Int32(Date().timeIntervalSince1970)
                sale.source = "shopify"
                sale.orderNumber = orderNumber
                sale.saleDate = saleDate
                sale.totalAmount = totalAmount
                sale.fulfillmentStatus = fulfillmentStatus
                isNew = true
            }
            
            // Process line items (only for new orders to avoid duplicates)
            if isNew {
                for lineItemEdge in lineItemEdges {
                    guard let lineItemNode = lineItemEdge["node"] as? [String: Any],
                          let sku = lineItemNode["sku"] as? String,
                          !sku.isEmpty,
                          let quantity = lineItemNode["quantity"] as? Int else {
                        continue
                    }
                    
                    // Parse unit price
                    var unitPrice: NSDecimalNumber = NSDecimalNumber.zero
                    if let priceSet = lineItemNode["originalUnitPriceSet"] as? [String: Any],
                       let shopMoney = priceSet["shopMoney"] as? [String: Any],
                       let amountString = shopMoney["amount"] as? String {
                        unitPrice = NSDecimalNumber(string: amountString)
                    }
                    
                    // Find inventory item using synchronous Core Data fetch
                    let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
                    fetchRequest.predicate = NSPredicate(format: "sku == %@", sku)
                    fetchRequest.fetchLimit = 1
                    
                    let items = try? context.fetch(fetchRequest)
                    
                    if let item = items?.first {
                        // Create line item
                        let lineItem = SaleLineItem(context: context)
                        lineItem.id = Int32(Date().timeIntervalSince1970) + Int32.random(in: 1...1000)
                        lineItem.quantity = Int32(quantity)
                        lineItem.unitPrice = unitPrice
                        lineItem.lineTotal = unitPrice.multiplying(by: NSDecimalNumber(value: quantity))
                        lineItem.item = item
                        lineItem.sale = sale
                    } else {
                        print("⚠️ SKU \(sku) not found in inventory, skipping line item")
                    }
                }
            }
            
            try context.save()
            
            return (isNew, !isNew)
        }
    }
    
    /// Map Shopify fulfillment status to our app's status
    private func mapShopifyFulfillmentStatus(_ shopifyStatus: String) -> String {
        switch shopifyStatus.uppercased() {
        case "UNFULFILLED":
            return "needs_fulfillment"
        case "PARTIALLY_FULFILLED", "IN_PROGRESS":
            return "in_transit"
        case "FULFILLED":
            return "delivered"
        case "SCHEDULED", "ON_HOLD":
            return "needs_fulfillment"
        default:
            return "needs_fulfillment"
        }
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
}
