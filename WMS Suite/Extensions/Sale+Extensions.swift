//
//  Sale+Extensions.swift
//  WMS Suite
//
//  Extensions for Sale entity
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
        request.predicate = NSPredicate(format: "ANY lineItems.item == %@", item)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
    
    // Fetch sales by source
    static func fetchSales(bySource source: OrderSource, context: NSManagedObjectContext) -> [Sale] {
        let request = NSFetchRequest<Sale>(entityName: "Sale")
        request.predicate = NSPredicate(format: "source == %@", source.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - Computed Properties
    
    // Get source as enum (handles nil gracefully)
    var orderSource: OrderSource? {
        guard let sourceString = source else { return nil }
        return OrderSource(rawValue: sourceString)
    }
    
    // Set source from enum
    func setSource(_ orderSource: OrderSource) {
        source = orderSource.rawValue
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
                return result + (lineTotal as Decimal)
            }
            return result
        }
    }
    
    // Get all unique items in this sale
    var uniqueItems: [InventoryItem] {
        guard let items = lineItems as? Set<SaleLineItem> else { return [] }
        return items.compactMap { $0.item }
    }
    
    // Count of unique items (not quantities)
    var itemCount: Int {
        guard let items = lineItems as? Set<SaleLineItem> else { return 0 }
        return items.count
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
