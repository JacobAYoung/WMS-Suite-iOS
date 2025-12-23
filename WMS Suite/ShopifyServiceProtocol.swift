//
//  ShopifyServiceProtocol.swift
//  WMS Suite
//
//  Updated with order sync method
//

import Foundation
import CoreData

protocol ShopifyServiceProtocol {
    func syncInventory(localItems: [InventoryItem], repo: InventoryRepositoryProtocol, logMismatch: @escaping (String) -> Void) async throws
    func fetchRecentSales(for item: InventoryItem) async throws -> [SalesHistoryDisplay]
    func pushItem(_ item: InventoryItem) async throws -> String
    
    /// ✅ NEW: Sync orders from Shopify with pagination
    func syncOrders(context: NSManagedObjectContext, logMessage: @escaping (String) -> Void) async throws
}
