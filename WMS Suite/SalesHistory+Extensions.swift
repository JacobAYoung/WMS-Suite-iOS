//
//  SalesHistory+Extensions.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import Foundation
import CoreData

extension SalesHistory {
    // Helper to get the related inventory item (if relationship exists)
    // For now, we'll search by matching criteria since we don't have itemSKU
    static func fetchSales(for item: InventoryItem, context: NSManagedObjectContext) -> [SalesHistory] {
        let request = NSFetchRequest<SalesHistory>(entityName: "SalesHistory")
        // Since we don't have itemSKU field, we'll return all sales for now
        // TODO: Add relationship or itemSKU field to properly filter
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SalesHistory.saleDate, ascending: false)]
        
        return (try? context.fetch(request)) ?? []
    }
}
