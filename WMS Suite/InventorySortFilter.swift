//
//  InventorySortFilter.swift
//  WMS Suite
//
//  Sorting and filtering options for inventory
//  FIXED: Changed photo.badge.minus to photo.badge.plus
//

import Foundation

enum InventorySortOption: String, CaseIterable, Identifiable {
    case nameAZ = "Name (A-Z)"
    case nameZA = "Name (Z-A)"
    case skuAZ = "SKU (A-Z)"
    case skuZA = "SKU (Z-A)"
    case quantityLowHigh = "Quantity (Low → High)"
    case quantityHighLow = "Quantity (High → Low)"
    case lowStock = "Low Stock First"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case needsSync = "Needs Sync First"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .nameAZ, .nameZA:
            return "textformat"
        case .skuAZ, .skuZA:
            return "barcode"
        case .quantityLowHigh, .quantityHighLow:
            return "number"
        case .lowStock:
            return "exclamationmark.triangle"
        case .newestFirst, .oldestFirst:
            return "clock"
        case .needsSync:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    func sort(_ items: [InventoryItem]) -> [InventoryItem] {
        switch self {
        case .nameAZ:
            return items.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        case .nameZA:
            return items.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedDescending }
        case .skuAZ:
            return items.sorted { ($0.sku ?? "").localizedCaseInsensitiveCompare($1.sku ?? "") == .orderedAscending }
        case .skuZA:
            return items.sorted { ($0.sku ?? "").localizedCaseInsensitiveCompare($1.sku ?? "") == .orderedDescending }
        case .quantityLowHigh:
            return items.sorted { $0.quantity < $1.quantity }
        case .quantityHighLow:
            return items.sorted { $0.quantity > $1.quantity }
        case .lowStock:
            return items.sorted { item1, item2 in
                let item1BelowMin = item1.quantity < item1.minStockLevel
                let item2BelowMin = item2.quantity < item2.minStockLevel
                
                if item1BelowMin && !item2BelowMin {
                    return true
                } else if !item1BelowMin && item2BelowMin {
                    return false
                } else {
                    return item1.quantity < item2.quantity
                }
            }
        case .newestFirst:
            return items.sorted { ($0.lastUpdated ?? Date.distantPast) > ($1.lastUpdated ?? Date.distantPast) }
        case .oldestFirst:
            return items.sorted { ($0.lastUpdated ?? Date.distantPast) < ($1.lastUpdated ?? Date.distantPast) }
        case .needsSync:
            return items.sorted { item1, item2 in
                let item1NeedsSync = item1.needsShopifySync || item1.needsQuickBooksSync
                let item2NeedsSync = item2.needsShopifySync || item2.needsQuickBooksSync
                
                if item1NeedsSync && !item2NeedsSync {
                    return true
                } else if !item1NeedsSync && item2NeedsSync {
                    return false
                } else {
                    return (item1.name ?? "").localizedCaseInsensitiveCompare(item2.name ?? "") == .orderedAscending
                }
            }
        }
    }
}

enum InventoryFilterOption: String, CaseIterable, Identifiable {
    case all = "All Items"
    case lowStock = "Low Stock"
    case outOfStock = "Out of Stock"
    case shopify = "From Shopify"
    case quickbooks = "From QuickBooks"
    case local = "Local Only"
    case needsSync = "Needs Sync"
    case hasImage = "Has Image"
    case noImage = "No Image"
    case byTag = "By Tag"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .lowStock:
            return "exclamationmark.triangle"
        case .outOfStock:
            return "xmark.circle"
        case .shopify:
            return "cart"
        case .quickbooks:
            return "book"
        case .local:
            return "iphone"
        case .needsSync:
            return "arrow.triangle.2.circlepath"
        case .hasImage:
            return "photo"
        case .noImage:
            return "photo.badge.plus"
        case .byTag:
            return "tag"
        }
    }
    
    func filter(_ items: [InventoryItem], selectedTag: ProductTag? = nil) -> [InventoryItem] {
        switch self {
        case .all:
            return items
        case .lowStock:
            return items.filter { $0.quantity < $0.minStockLevel && $0.quantity > 0 }
        case .outOfStock:
            return items.filter { $0.quantity == 0 }
        case .shopify:
            return items.filter { $0.existsIn(.shopify) }
        case .quickbooks:
            return items.filter { $0.existsIn(.quickbooks) }
        case .local:
            return items.filter { !$0.existsIn(.shopify) && !$0.existsIn(.quickbooks) }
        case .needsSync:
            return items.filter { $0.needsShopifySync || $0.needsQuickBooksSync }
        case .hasImage:
            return items.filter { $0.imageUrl != nil && !($0.imageUrl?.isEmpty ?? true) }
        case .noImage:
            return items.filter { $0.imageUrl == nil || ($0.imageUrl?.isEmpty ?? true) }
        case .byTag:
            guard let selectedTag = selectedTag else { return items }
            return items.filter { item in
                item.tags.contains(where: { $0.id == selectedTag.id })
            }
        }
    }
}
