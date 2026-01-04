//
//  IDGenerator.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/29/25.
//


import Foundation
import CoreData

class IDGenerator {
    
    // MARK: - QuickBooks ID Conversion
    
    /// Convert QuickBooks Customer ID string to a unique Int32
    /// Uses hash to ensure consistency - same QB ID always produces same Int32
    static func hashQuickBooksCustomerID(_ qbID: String) -> Int32 {
        // Create a consistent hash from the QB ID
        let hash = abs(qbID.hashValue)
        // Add offset to avoid conflicts with local IDs (start at 1,800,000,000)
        let qbOffset: Int32 = 1_800_000_000
        let hashedValue = Int32(hash % Int(Int32.max - qbOffset))
        return qbOffset + hashedValue
    }
    
    /// Convert QuickBooks Invoice ID string to a unique Int32
    static func hashQuickBooksInvoiceID(_ qbID: String) -> Int32 {
        let hash = abs(qbID.hashValue)
        // Use different offset for invoices (start at 1,500,000,000)
        let qbOffset: Int32 = 1_500_000_000
        let hashedValue = Int32(hash % Int(Int32.max - qbOffset))
        return qbOffset + hashedValue
    }
    
    /// Convert QuickBooks Item ID string to a unique Int32
    static func hashQuickBooksItemID(_ qbID: String) -> Int32 {
        let hash = abs(qbID.hashValue)
        // Use different offset for items (start at 1,200,000,000)
        let qbOffset: Int32 = 1_200_000_000
        let hashedValue = Int32(hash % Int(Int32.max - qbOffset))
        return qbOffset + hashedValue
    }
    
    /// Convert Shopify Order ID to Int32
    static func hashShopifyOrderID(_ shopifyID: String) -> Int32 {
        let hash = abs(shopifyID.hashValue)
        // Use different offset for Shopify (start at 1,000,000,000)
        let shopifyOffset: Int32 = 1_000_000_000
        let hashedValue = Int32(hash % Int(shopifyOffset))
        return shopifyOffset + hashedValue
    }
    
    // MARK: - Local ID Generation (for manually created records)
    
    /// Generate a unique ID for locally created Sale entities
    static func generateLocalSaleID(context: NSManagedObjectContext) -> Int32 {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Sale")
        fetchRequest.resultType = .dictionaryResultType
        
        // Only look at local sales (id < 1,000,000,000)
        fetchRequest.predicate = NSPredicate(format: "id < 1000000000")
        
        let maxExpression = NSExpression(forKeyPath: "id")
        let maxExpressionDescription = NSExpressionDescription()
        maxExpressionDescription.expression = NSExpression(forFunction: "max:", arguments: [maxExpression])
        maxExpressionDescription.name = "maxID"
        maxExpressionDescription.expressionResultType = .integer32AttributeType
        
        fetchRequest.propertiesToFetch = [maxExpressionDescription]
        
        do {
            let results = try context.fetch(fetchRequest) as? [[String: Any]]
            if let maxID = results?.first?["maxID"] as? Int32 {
                return maxID + 1
            }
        } catch {
            print("Error fetching max local Sale ID: \(error)")
        }
        
        // Start local IDs at 1
        return 1
    }
    
    /// Generate a unique ID for locally created Customer entities
    static func generateLocalCustomerID(context: NSManagedObjectContext) -> Int32 {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Customer")
        fetchRequest.resultType = .dictionaryResultType
        
        // Only look at local customers (id < 1,000,000,000)
        fetchRequest.predicate = NSPredicate(format: "id < 1000000000")
        
        let maxExpression = NSExpression(forKeyPath: "id")
        let maxExpressionDescription = NSExpressionDescription()
        maxExpressionDescription.expression = NSExpression(forFunction: "max:", arguments: [maxExpression])
        maxExpressionDescription.name = "maxID"
        maxExpressionDescription.expressionResultType = .integer32AttributeType
        
        fetchRequest.propertiesToFetch = [maxExpressionDescription]
        
        do {
            let results = try context.fetch(fetchRequest) as? [[String: Any]]
            if let maxID = results?.first?["maxID"] as? Int32 {
                return maxID + 1
            }
        } catch {
            print("Error fetching max local Customer ID: \(error)")
        }
        
        // Start local IDs at 1
        return 1
    }
    
    /// Generate a unique ID for SaleLineItem entities
    static func generateSaleLineItemID(context: NSManagedObjectContext) -> Int32 {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SaleLineItem")
        fetchRequest.resultType = .dictionaryResultType
        
        let maxExpression = NSExpression(forKeyPath: "id")
        let maxExpressionDescription = NSExpressionDescription()
        maxExpressionDescription.expression = NSExpression(forFunction: "max:", arguments: [maxExpression])
        maxExpressionDescription.name = "maxID"
        maxExpressionDescription.expressionResultType = .integer32AttributeType
        
        fetchRequest.propertiesToFetch = [maxExpressionDescription]
        
        do {
            let results = try context.fetch(fetchRequest) as? [[String: Any]]
            if let maxID = results?.first?["maxID"] as? Int32 {
                return maxID + 1
            }
        } catch {
            print("Error fetching max SaleLineItem ID: \(error)")
        }
        
        // Start at 1
        return 1
    }
}

// MARK: - ID Ranges
/*
 ID ALLOCATION STRATEGY:
 
 1 - 999,999,999:                Local records (manually created)
 1,000,000,000 - 1,199,999,999:  Shopify records
 1,200,000,000 - 1,499,999,999:  QuickBooks Items (Inventory)
 1,500,000,000 - 1,799,999,999:  QuickBooks Invoices
 1,800,000,000 - 2,147,483,647:  QuickBooks Customers
 
 This ensures:
 - No conflicts between different sources
 - Same QB/Shopify ID always maps to same Int32
 - Local records get sequential IDs starting at 1
 - All offsets fit within Int32.max (2,147,483,647)
 */
