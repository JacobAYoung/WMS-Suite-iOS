//
//  InventoryViewModel.swift
//  WMS Suite
//
//  Updated: Proper data refresh and Core Data change notifications
//

import Foundation
import CoreData
import Combine
import UIKit

class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var isLoading = false
    @Published var showingSyncAlert = false
    @Published var syncMessage = ""
    @Published var errorMessage: String?
    @Published var showingError = false
    
    private let repository: InventoryRepositoryProtocol
    let shopifyService: ShopifyServiceProtocol // Made public for reorder recommendations
    private let quickbooksService: QuickBooksServiceProtocol
    private let barcodeService: BarcodeServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: InventoryRepositoryProtocol,
         shopifyService: ShopifyServiceProtocol,
         quickbooksService: QuickBooksServiceProtocol,
         barcodeService: BarcodeServiceProtocol) {
        self.repository = repository
        self.shopifyService = shopifyService
        self.quickbooksService = quickbooksService
        self.barcodeService = barcodeService
        
        // ✅ NEW: Listen for Core Data changes
        setupCoreDataObserver()
        
        fetchItems()
    }
    
    // ✅ NEW: Setup Core Data change observer
    private func setupCoreDataObserver() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Only refresh if we're not currently loading
                guard let self = self, !self.isLoading else { return }
                Task {
                    await self.fetchItemsImmediately()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Inventory Management
    
    /// Fetch items from local database (immediate, no loading indicator)
    @MainActor
    private func fetchItemsImmediately() async {
        do {
            let fetchedItems = try await repository.fetchAllItems()
            // ✅ CRITICAL: Create a NEW array to force SwiftUI to detect change
            self.items = []
            self.items = fetchedItems
            self.objectWillChange.send()
        } catch {
            print("❌ Failed to fetch items: \(error.localizedDescription)")
        }
    }
    
    /// Fetch items from local database
    func fetchItems() {
        Task { @MainActor in
            do {
                let fetchedItems = try await repository.fetchAllItems()
                print("✅ Fetched \(fetchedItems.count) items from database")
                
                // ✅ CRITICAL: Create a NEW array to force SwiftUI to detect change
                self.items = []
                self.items = fetchedItems
                
                // Force objectWillChange to fire
                self.objectWillChange.send()
            } catch {
                handleError("Failed to load items", error: error)
            }
        }
    }
    
    /// ✅ NEW: Comprehensive refresh from all sources
    func refreshAllData() {
        isLoading = true
        
        Task { @MainActor in
            var logs: [String] = []
            var hasErrors = false
            
            // 1. Refresh local data first
            do {
                items = try await repository.fetchAllItems()
                logs.append("✅ Local data refreshed")
            } catch {
                logs.append("❌ Failed to refresh local data: \(error.localizedDescription)")
                hasErrors = true
            }
            
            // 2. Sync with Shopify (if configured)
            let shopifyConfigured = !(UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? "").isEmpty &&
                                    !(UserDefaults.standard.string(forKey: "shopifyAccessToken") ?? "").isEmpty
            
            if shopifyConfigured {
                do {
                    try await syncShopifyData { message in
                        logs.append(message)
                    }
                    logs.append("✅ Shopify sync completed")
                } catch {
                    logs.append("❌ Shopify sync failed: \(error.localizedDescription)")
                    hasErrors = true
                }
            } else {
                logs.append("⚠️ Shopify not configured")
            }
            
            // 3. Sync with QuickBooks (if configured and authenticated)
            let qbConfigured = QuickBooksTokenManager.shared.isAuthenticated
            
            if qbConfigured {
                do {
                    try await syncQuickBooksData()
                    logs.append("✅ QuickBooks sync completed")
                } catch {
                    logs.append("❌ QuickBooks sync failed: \(error.localizedDescription)")
                    hasErrors = true
                }
            } else {
                logs.append("⚠️ QuickBooks not configured")
            }
            
            // 4. Final refresh of local data
            do {
                items = try await repository.fetchAllItems()
            } catch {
                logs.append("❌ Failed to reload items after sync")
                hasErrors = true
            }
            
            // Show results
            syncMessage = logs.joined(separator: "\n")
            showingSyncAlert = true
            isLoading = false
        }
    }
    
    /// ✅ NEW: Sync QuickBooks data
    private func syncQuickBooksData() async throws {
        // Get QuickBooks credentials from Keychain (more secure)
        let accessToken = KeychainHelper.shared.getQBAccessToken() ?? ""
        let refreshToken = KeychainHelper.shared.getQBRefreshToken() ?? ""
        let companyId = KeychainHelper.shared.getQBRealmId() ?? ""
        let useSandbox = UserDefaults.standard.bool(forKey: "quickbooksUseSandbox")
        
        guard !companyId.isEmpty && !accessToken.isEmpty else {
            throw AppError.missingCredentials("QuickBooks not configured")
        }
        
        // Create service and sync inventory
        let service = QuickBooksService(
            companyId: companyId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            useSandbox: useSandbox
        )
        
        let context = PersistenceController.shared.container.viewContext
        
        // Sync inventory items from QuickBooks
        try await service.syncInventory(context: context) { message in
            print("📦 QB Inventory Sync: \(message)")
        }
        
        // Note: Items will be fetched fresh from DB after this completes
    }
    
    /// ✅ NEW: Sync Shopify data (extracted from syncWithShopify)
    private func syncShopifyData(logMismatch: @escaping (String) -> Void) async throws {
        let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? ""
        let accessToken = UserDefaults.standard.string(forKey: "shopifyAccessToken") ?? ""
        
        if let service = shopifyService as? ShopifyService {
            service.updateCredentials(storeUrl: storeUrl, accessToken: accessToken)
        }
        
        try await shopifyService.syncInventory(
            localItems: items,
            repo: repository,
            logMismatch: logMismatch
        )
    }
    
    func addItem(sku: String, name: String, description: String?, upc: String?, webSKU: String?, quantity: Decimal, minStockLevel: Decimal, imageUrl: String? = nil) {
        Task { @MainActor in
            do {
                let newItem = try await repository.createItem(
                    sku: sku,
                    name: name,
                    description: description,
                    upc: upc,
                    webSKU: webSKU,
                    quantity: quantity,
                    minStockLevel: minStockLevel,
                    imageUrl: imageUrl
                )
                // Note: fetchItems() will be called automatically via Core Data observer
            } catch {
                handleError("Failed to add item", error: error)
            }
        }
    }
    
    func updateItem(_ item: InventoryItem, sku: String, name: String, description: String?, upc: String?, webSKU: String?, quantity: Decimal, minStockLevel: Decimal) {
        Task { @MainActor in
            do {
                item.sku = sku
                item.name = name
                item.itemDescription = description
                item.upc = upc
                item.webSKU = webSKU
                item.quantity = NSDecimalNumber(decimal: quantity)
                item.minStockLevel = NSDecimalNumber(decimal: minStockLevel)
                item.lastUpdated = Date()
                try await repository.updateItem(item)
                // Note: fetchItems() will be called automatically via Core Data observer
            } catch {
                handleError("Failed to update item", error: error)
            }
        }
    }
    
    func deleteItem(_ item: InventoryItem) {
        Task { @MainActor in
            do {
                try await repository.deleteItem(item)
                // Note: fetchItems() will be called automatically via Core Data observer
            } catch {
                handleError("Failed to delete item", error: error)
            }
        }
    }
    
    // MARK: - Shopify Integration (Legacy - kept for compatibility)
    
    func syncWithShopify() {
        let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? ""
        let accessToken = UserDefaults.standard.string(forKey: "shopifyAccessToken") ?? ""
        
        if let service = shopifyService as? ShopifyService {
            service.updateCredentials(storeUrl: storeUrl, accessToken: accessToken)
        }
        
        isLoading = true
        var logs: [String] = []
        
        Task { @MainActor in
            do {
                try await shopifyService.syncInventory(
                    localItems: items,
                    repo: repository
                ) { message in
                    logs.append(message)
                }
                
                items = try await repository.fetchAllItems()
                
                syncMessage = logs.isEmpty ? "Sync completed successfully" : logs.joined(separator: "\n")
                showingSyncAlert = true
                isLoading = false
            } catch {
                let errorMsg: String
                if let networkError = error as? NetworkError {
                    errorMsg = networkError.localizedDescription
                } else if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        errorMsg = "No internet connection. Please check your network and try again."
                    case .networkConnectionLost:
                        errorMsg = "Network connection was lost. Please try again."
                    case .timedOut:
                        errorMsg = "Request timed out. Shopify may be slow to respond."
                    default:
                        errorMsg = "Sync failed: \(error.localizedDescription)"
                    }
                } else {
                    errorMsg = "Sync failed: \(error.localizedDescription)"
                }
                
                syncMessage = errorMsg
                showingSyncAlert = true
                isLoading = false
            }
        }
    }
    
    func pushToShopify(item: InventoryItem) async throws {
        let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? ""
        let accessToken = UserDefaults.standard.string(forKey: "shopifyAccessToken") ?? ""
        
        guard !storeUrl.isEmpty && !accessToken.isEmpty else {
            throw AppError.missingCredentials("Shopify credentials not configured")
        }
        
        if let service = shopifyService as? ShopifyService {
            service.updateCredentials(storeUrl: storeUrl, accessToken: accessToken)
        }
        
        do {
            let productId = try await shopifyService.pushItem(item)
            
            await MainActor.run {
                item.shopifyProductId = productId
                item.lastSyncedShopifyDate = Date()
                
                Task {
                    try? await repository.updateItem(item)
                    // Note: fetchItems() will be called automatically via Core Data observer
                }
            }
        } catch {
            await MainActor.run {
                handleError("Failed to push to Shopify", error: error)
            }
            throw error
        }
    }
    
    // MARK: - QuickBooks Integration
    func pushToQuickBooks(item: InventoryItem) async throws {
        // Get credentials from Keychain
        let accessToken = KeychainHelper.shared.getQBAccessToken() ?? ""
        let refreshToken = KeychainHelper.shared.getQBRefreshToken() ?? ""
        let companyId = KeychainHelper.shared.getQBRealmId() ?? ""
        let useSandbox = UserDefaults.standard.bool(forKey: "quickbooksUseSandbox")
        
        guard !companyId.isEmpty && !accessToken.isEmpty else {
            throw AppError.missingCredentials("QuickBooks credentials not configured")
        }
        
        let service = QuickBooksService(
            companyId: companyId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            useSandbox: useSandbox
        )
        
        do {
            let itemId = try await service.pushInventoryItem(item)
            
            await MainActor.run {
                item.quickbooksItemId = itemId
                item.lastSyncedQuickbooksDate = Date()
                
                Task {
                    try? await repository.updateItem(item)
                    // Note: fetchItems() will be called automatically via Core Data observer
                }
            }
        } catch {
            await MainActor.run {
                handleError("Failed to push to QuickBooks", error: error)
            }
            throw error
        }
    }

    // MARK: - Forecasting
    func calculateForecast(for item: InventoryItem, days: Int) async -> ForecastResult? {
        do {
            // Fetch sales history - now returns [SalesHistoryDisplay]
            let salesHistory = try await shopifyService.fetchRecentSales(for: item)
            
            if salesHistory.isEmpty {
                return ForecastResult(
                    item: item,
                    averageDailySales: 0.0,
                    projectedSales: 0,
                    daysUntilStockout: 999,
                    recommendedOrderQuantity: 0
                )
            }
            
            // Calculate total sold from the display objects
            let totalSold = salesHistory.reduce(0) { $0 + Int($1.quantity) }
            let averageDailySales = Double(totalSold) / Double(salesHistory.count)
            let projectedSales = averageDailySales * Double(days)
            
            let currentStock = Double(item.quantity)
            let daysUntilStockout = averageDailySales > 0 ? currentStock / averageDailySales : 999
            let recommendedOrder = max(0, projectedSales - currentStock)
            
            return ForecastResult(
                item: item,
                averageDailySales: averageDailySales,
                projectedSales: Int(projectedSales),
                daysUntilStockout: Int(daysUntilStockout),
                recommendedOrderQuantity: Int(recommendedOrder)
            )
        } catch {
            await MainActor.run {
                handleError("Failed to calculate forecast", error: error)
            }
            return nil
        }
    }
    
    // MARK: - Barcode Generation
    func generateBarcode(for item: InventoryItem) -> BarcodeData? {
        let data = item.upc ?? item.sku ?? ""
        guard !data.isEmpty else { return nil }
        
        let image = barcodeService.generateBarcode(data: data, label: item.name ?? "")
        return BarcodeData(item: item, image: image, data: data)
    }
    
    func printBarcode(_ barcodeData: BarcodeData, copies: Int = 1) {
        for _ in 0..<copies {
            barcodeService.printBarcode(barcodeData.image)
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ message: String, error: Error) {
        let userMessage: String
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                userMessage = "No internet connection"
            case .timedOut:
                userMessage = "Request timed out"
            default:
                userMessage = error.localizedDescription
            }
        } else {
            userMessage = error.localizedDescription
        }
        
        errorMessage = "\(message): \(userMessage)"
        showingError = true
        print("❌ \(message): \(userMessage)")
    }
}

// MARK: - App Error Types
enum AppError: LocalizedError {
    case missingCredentials(String)
    case syncFailed(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials(let message):
            return message
        case .syncFailed(let message):
            return message
        case .networkError(let message):
            return message
        }
    }
}
