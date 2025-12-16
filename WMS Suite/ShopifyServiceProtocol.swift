//
//  ShopifyServiceProtocol.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation

protocol ShopifyServiceProtocol {
    func syncInventory(localItems: [InventoryItem], repo: InventoryRepositoryProtocol, logMismatch: @escaping (String) -> Void) async throws
    func fetchRecentSales(for item: InventoryItem) async throws -> [SalesHistory]
    func pushItem(_ item: InventoryItem) async throws -> String
}
