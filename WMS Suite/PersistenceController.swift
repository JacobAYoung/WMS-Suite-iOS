//
//  PersistenceController.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        for i in 0..<10 {
            let newItem = InventoryItem(context: viewContext)
            // Don't set id - it's auto-generated
            newItem.sku = "SKU-\(String(format: "%03d", i))"
            newItem.name = "Sample Item \(i)"
            newItem.itemDescription = "This is a sample inventory item"
            newItem.upc = "12345678\(i)"
            newItem.quantity = NSDecimalNumber(value: Int32.random(in: 0...100))
            newItem.minStockLevel = NSDecimalNumber(value: 10)
            newItem.lastUpdated = Date()
        }
        
        // Create some sample sales
        for i in 0..<5 {
            let sale = Sale(context: viewContext)
            // Don't set id - it's auto-generated
            sale.saleDate = Date().addingTimeInterval(-Double(i) * 86400) // Days ago
            sale.orderNumber = "ORDER-\(1000 + i)"
            
            // Add 1-3 line items per sale
            let numLineItems = Int.random(in: 1...3)
            for j in 0..<numLineItems {
                let lineItem = SaleLineItem(context: viewContext)
                // Don't set id - it's auto-generated
                lineItem.quantity = NSDecimalNumber(value: Int32.random(in: 1...10))
                lineItem.sale = sale
                // Randomly assign to an item (would need to fetch items in real scenario)
            }
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WMS_Suite")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
