//
//  InventoryRepository.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation
import CoreData

class InventoryRepository: InventoryRepositoryProtocol {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchAllItems() async throws -> [InventoryItem] {
        return try await context.perform {
            let request = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.name, ascending: true)]
            return try self.context.fetch(request)
        }
    }
    
    func createItem(sku: String, name: String, description: String?, upc: String?, webSKU: String?, quantity: Int32, minStockLevel: Int32, imageUrl: String?) async throws -> InventoryItem {
        return try await context.perform {
            let item = InventoryItem(context: self.context)
            item.id = Int32(Date().timeIntervalSince1970)
            item.sku = sku
            item.name = name
            item.itemDescription = description
            item.upc = upc
            item.webSKU = webSKU
            item.quantity = quantity
            item.minStockLevel = minStockLevel
            item.imageUrl = imageUrl
            item.lastUpdated = Date()
            
            try self.context.save()
            return item
        }
    }
    
    func updateItem(_ item: InventoryItem) async throws {
        try await context.perform {
            item.lastUpdated = Date()
            try self.context.save()
        }
    }
    
    func deleteItem(_ item: InventoryItem) async throws {
        try await context.perform {
            self.context.delete(item)
            try self.context.save()
        }
    }
    
    func findItem(bySKU sku: String) async throws -> InventoryItem? {
        return try await context.perform {
            let request = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
            request.predicate = NSPredicate(format: "sku == %@", sku)
            request.fetchLimit = 1
            return try self.context.fetch(request).first
        }
    }
}
