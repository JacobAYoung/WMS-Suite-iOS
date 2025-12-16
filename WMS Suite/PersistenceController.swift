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
            newItem.id = Int32(i + 1)  // Changed from UUID() to Int32
            newItem.sku = "SKU-\(String(format: "%03d", i))"
            newItem.name = "Sample Item \(i)"
            newItem.itemDescription = "This is a sample inventory item"
            newItem.upc = "12345678\(i)"
            newItem.quantity = Int32.random(in: 0...100)
            newItem.minStockLevel = 10
            newItem.lastUpdated = Date()
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
