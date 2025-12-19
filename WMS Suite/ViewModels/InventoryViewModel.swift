//
//  InventoryViewModel.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
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
    private let shopifyService: ShopifyServiceProtocol
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
        fetchItems()
    }
    
    // MARK: - Inventory Management
    func fetchItems() {
        isLoading = true
        Task { @MainActor in
            do {
                items = try await repository.fetchAllItems()
                isLoading = false
            } catch {
                handleError("Failed to load items", error: error)
                isLoading = false
            }
        }
    }
    
    func addItem(sku: String, name: String, description: String?, upc: String?, webSKU: String?, quantity: Int32, minStockLevel: Int32, imageUrl: String? = nil) {
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
                items.append(newItem)
                items.sort { ($0.name ?? "") < ($1.name ?? "") }
            } catch {
                handleError("Failed to add item", error: error)
            }
        }
    }
    
    func updateItem(_ item: InventoryItem, sku: String, name: String, description: String?, upc: String?, webSKU: String?, quantity: Int32, minStockLevel: Int32) {
        Task { @MainActor in
            do {
                item.sku = sku
                item.name = name
                item.itemDescription = description
                item.upc = upc
                item.webSKU = webSKU
                item.quantity = quantity
                item.minStockLevel = minStockLevel
                item.lastUpdated = Date()
                try await repository.updateItem(item)
                fetchItems()
            } catch {
                handleError("Failed to update item", error: error)
            }
        }
    }
    
    func deleteItem(_ item: InventoryItem) {
        Task { @MainActor in
            do {
                try await repository.deleteItem(item)
                items.removeAll { $0.id == item.id }
            } catch {
                handleError("Failed to delete item", error: error)
            }
        }
    }
    
    // MARK: - Shopify Integration
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
                    fetchItems()
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
        let companyId = UserDefaults.standard.string(forKey: "quickbooksCompanyId") ?? ""
        let accessToken = UserDefaults.standard.string(forKey: "quickbooksAccessToken") ?? ""
        
        guard !companyId.isEmpty && !accessToken.isEmpty else {
            throw AppError.missingCredentials("QuickBooks credentials not configured")
        }
        
        let service = QuickBooksService(
            companyId: companyId,
            accessToken: accessToken,
            refreshToken: UserDefaults.standard.string(forKey: "quickbooksRefreshToken") ?? ""
        )
        
        do {
            let itemId = try await quickbooksService.pushItem(item)
            
            await MainActor.run {
                item.quickbooksItemId = itemId
                item.lastSyncedQuickbooksDate = Date()
                
                Task {
                    try? await repository.updateItem(item)
                    fetchItems()
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
