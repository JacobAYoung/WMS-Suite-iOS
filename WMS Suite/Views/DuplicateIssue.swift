//
//  DuplicateIssue.swift
//  WMS Suite
//
//  Model for duplicate detection issues
//

import Foundation
import SwiftUI

// MARK: - Duplicate Issue Types

enum DuplicateIssueType: String, CaseIterable {
    case duplicateSKU = "Duplicate SKU"
    case duplicateUPC = "Duplicate UPC"
    
    var icon: String {
        switch self {
        case .duplicateSKU:
            return "tag.fill"
        case .duplicateUPC:
            return "barcode.viewfinder"
        }
    }
    
    var color: Color {
        switch self {
        case .duplicateSKU:
            return .red
        case .duplicateUPC:
            return .orange
        }
    }
    
    var severity: Int {
        // Both are high priority
        return 3
    }
}

// MARK: - Duplicate Issue Model

struct DuplicateIssue: Identifiable {
    let id = UUID()
    let type: DuplicateIssueType
    let value: String // The duplicate SKU/UPC/etc
    let items: [InventoryItem]
    let description: String
    let recommendation: String
    
    var severityText: String {
        return "High"
    }
}

// MARK: - Duplicate Detection Service

class DuplicateDetectionService {
    
    /// Analyze inventory for all duplicate issues
    static func analyzeInventory(_ items: [InventoryItem]) -> [DuplicateIssue] {
        var issues: [DuplicateIssue] = []
        
        // Check for duplicate SKUs
        issues.append(contentsOf: findDuplicateSKUs(items))
        
        // Check for duplicate UPCs
        issues.append(contentsOf: findDuplicateUPCs(items))
        
        return issues.sorted { $0.type.severity > $1.type.severity }
    }
    
    // MARK: - Detection Methods
    
    private static func findDuplicateSKUs(_ items: [InventoryItem]) -> [DuplicateIssue] {
        var skuGroups: [String: [InventoryItem]] = [:]
        
        for item in items {
            guard let sku = item.sku, !sku.isEmpty else { continue }
            skuGroups[sku, default: []].append(item)
        }
        
        return skuGroups.compactMap { sku, items in
            guard items.count > 1 else { return nil }
            
            let itemNames = items.compactMap { $0.name }.joined(separator: ", ")
            
            return DuplicateIssue(
                type: .duplicateSKU,
                value: sku,
                items: items,
                description: "\(items.count) items share SKU '\(sku)': \(itemNames)",
                recommendation: "Each product should have a unique SKU. Review these items and update their SKUs in your inventory system (Shopify/QuickBooks) to be unique."
            )
        }
    }
    
    private static func findDuplicateUPCs(_ items: [InventoryItem]) -> [DuplicateIssue] {
        var upcGroups: [String: [InventoryItem]] = [:]
        
        for item in items {
            guard let upc = item.upc, !upc.isEmpty else { continue }
            upcGroups[upc, default: []].append(item)
        }
        
        return upcGroups.compactMap { upc, items in
            guard items.count > 1 else { return nil }
            
            let itemNames = items.compactMap { $0.name }.joined(separator: ", ")
            
            return DuplicateIssue(
                type: .duplicateUPC,
                value: upc,
                items: items,
                description: "\(items.count) items share UPC '\(upc)': \(itemNames)",
                recommendation: "UPC codes must be unique. If these are truly different products, assign unique UPCs. If they're the same product, consider merging them."
            )
        }
    }
}
