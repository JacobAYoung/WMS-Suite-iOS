//
//  Sale+Extensions.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/16/25.
//

import Foundation
import CoreData

extension Sale {
    // Fetch all sales
    static func fetchAllSales(context: NSManagedObjectContext) -> [Sale] {
        let request = NSFetchRequest<Sale>(entityName: "Sale")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
    
    // Fetch sales for a specific item
    static func fetchSales(for item: InventoryItem, context: NSManagedObjectContext) -> [Sale] {
        let request = NSFetchRequest<Sale>(entityName: "Sale")
        
        // Use a predicate to find sales that have line items with this inventory item
        request.predicate = NSPredicate(format: "ANY lineItems.item == %@", item)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)]
        
        return (try? context.fetch(request)) ?? []
    }
    
    // Calculated total quantity for this sale
    var totalQuantity: Int32 {
        guard let items = lineItems as? Set<SaleLineItem> else { return 0 }
        return items.reduce(0) { $0 + $1.quantity }
    }
    
    // Calculated total amount (if you add pricing)
    var calculatedTotal: Decimal {
        guard let items = lineItems as? Set<SaleLineItem> else { return 0 }
        return items.reduce(Decimal(0)) { result, lineItem in
            if let lineTotal = lineItem.lineTotal {
                return result + (lineTotal as Decimal)  // ✅ Cast NSDecimalNumber to Decimal
            }
            return result
        }
    }
    
    // Get all unique items in this sale
    var uniqueItems: [InventoryItem] {
        guard let items = lineItems as? Set<SaleLineItem> else { return [] }
        return items.compactMap { $0.item }
    }
}

extension SaleLineItem {
    // Get quantity sold for a specific item
    static func totalQuantitySold(for item: InventoryItem, context: NSManagedObjectContext) -> Int32 {
        let request = NSFetchRequest<SaleLineItem>(entityName: "SaleLineItem")
        request.predicate = NSPredicate(format: "item == %@", item)
        
        guard let lineItems = try? context.fetch(request) else { return 0 }
        return lineItems.reduce(0) { $0 + $1.quantity }
    }
}
