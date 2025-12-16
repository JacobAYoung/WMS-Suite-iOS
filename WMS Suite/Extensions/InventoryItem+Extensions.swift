//
//  InventoryItem+Extensions.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import Foundation
import SwiftUI

extension InventoryItem {
    // Computed property to determine where this item exists
    var itemSources: [ItemSource] {
        var sources: [ItemSource] = [.local] // Always exists locally if in the database
        
        if shopifyProductId != nil && !(shopifyProductId?.isEmpty ?? true) {
            sources.append(.shopify)
        }
        
        if quickbooksItemId != nil && !(quickbooksItemId?.isEmpty ?? true) {
            sources.append(.quickbooks)
        }
        
        return sources
    }
    
    // Get image URL or placeholder
    var displayImageUrl: URL? {
        if let urlString = imageUrl, let url = URL(string: urlString) {
            return url
        }
        return nil
    }
    
    // Check if item exists in a specific source
    func existsIn(_ source: ItemSource) -> Bool {
        return itemSources.contains(source)
    }
    
    // Get display name for scanning (UPC → SKU → webSKU)
    var scanIdentifier: String {
        return upc ?? sku ?? webSKU ?? "Unknown"
    }
    
    // Check if item needs sync to Shopify
    var needsShopifySync: Bool {
        guard let shopifyId = shopifyProductId, !shopifyId.isEmpty else {
            return false
        }
        
        guard let lastSynced = lastSyncedShopifyDate else {
            return true // Has Shopify ID but never synced
        }
        
        guard let lastUpdated = lastUpdated else {
            return false
        }
        
        return lastUpdated > lastSynced
    }
    
    // Check if item needs sync to QuickBooks
    var needsQuickBooksSync: Bool {
        guard let qbId = quickbooksItemId, !qbId.isEmpty else {
            return false
        }
        
        guard let lastSynced = lastSyncedQuickbooksDate else {
            return true
        }
        
        guard let lastUpdated = lastUpdated else {
            return false
        }
        
        return lastUpdated > lastSynced
    }
}

// Enum for item sources
enum ItemSource: String, CaseIterable {
    case local = "Local"
    case shopify = "Shopify"
    case quickbooks = "QuickBooks"
    
    var iconName: String {
        switch self {
        case .local:
            return "iphone"
        case .shopify:
            return "cart.fill"
        case .quickbooks:
            return "book.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .local:
            return .blue
        case .shopify:
            return .green
        case .quickbooks:
            return .orange
        }
    }
}
