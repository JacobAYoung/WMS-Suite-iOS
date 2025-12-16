//
//  InventoryRepositoryProtocol.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation

protocol InventoryRepositoryProtocol {
    func fetchAllItems() async throws -> [InventoryItem]
    func createItem(sku: String, name: String, description: String?, upc: String?, webSKU: String?, quantity: Int32, minStockLevel: Int32, imageUrl: String?) async throws -> InventoryItem
    func updateItem(_ item: InventoryItem) async throws
    func deleteItem(_ item: InventoryItem) async throws
    func findItem(bySKU sku: String) async throws -> InventoryItem?
}
