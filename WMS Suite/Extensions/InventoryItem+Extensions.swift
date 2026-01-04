//
//  InventoryItem+Extensions.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import Foundation
import SwiftUI

extension InventoryItem {
    // MARK: - UserDefaults Keys
    
    private var notesKey: String {
        guard let sku = self.sku, !sku.isEmpty else {
            return "item_notes_\(self.objectID.uriRepresentation().absoluteString)"
        }
        return "item_notes_\(sku)"
    }
    
    private var tagsKey: String {
        guard let sku = self.sku, !sku.isEmpty else {
            return "item_tags_\(self.objectID.uriRepresentation().absoluteString)"
        }
        return "item_tags_\(sku)"
    }
    
    private var costKey: String {
        guard let sku = self.sku, !sku.isEmpty else {
            return "item_cost_\(self.objectID.uriRepresentation().absoluteString)"
        }
        return "item_cost_\(sku)"
    }
    
    private var sellingPriceKey: String {
        guard let sku = self.sku, !sku.isEmpty else {
            return "item_selling_price_\(self.objectID.uriRepresentation().absoluteString)"
        }
        return "item_selling_price_\(sku)"
    }
    
    private var shopifyPriceKey: String {
        guard let sku = self.sku, !sku.isEmpty else {
            return "item_shopify_price_\(self.objectID.uriRepresentation().absoluteString)"
        }
        return "item_shopify_price_\(sku)"
    }
    
    private var quickbooksPriceKey: String {
        guard let sku = self.sku, !sku.isEmpty else {
            return "item_quickbooks_price_\(self.objectID.uriRepresentation().absoluteString)"
        }
        return "item_quickbooks_price_\(sku)"
    }
    
    private var quickbooksCostKey: String {
        guard let sku = self.sku, !sku.isEmpty else {
            return "item_quickbooks_cost_\(self.objectID.uriRepresentation().absoluteString)"
        }
        return "item_quickbooks_cost_\(sku)"
    }
    
    // MARK: - Cost & Pricing Properties
    
    // Cost (from QuickBooks or manual)
    var cost: Decimal {
        get {
            // Prefer QuickBooks cost, fall back to manual cost
            let qbCost = quickbooksCost
            if qbCost > 0 {
                return qbCost
            }
            let value = UserDefaults.standard.double(forKey: costKey)
            return Decimal(value)
        }
        set {
            UserDefaults.standard.set(NSDecimalNumber(decimal: newValue).doubleValue, forKey: costKey)
        }
    }
    
    // Shopify-specific price (retail/online)
    var shopifyPrice: Decimal? {
        get {
            let value = UserDefaults.standard.double(forKey: shopifyPriceKey)
            return value > 0 ? Decimal(value) : nil
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(NSDecimalNumber(decimal: newValue).doubleValue, forKey: shopifyPriceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: shopifyPriceKey)
            }
        }
    }
    
    // QuickBooks-specific price (wholesale/B2B)
    var quickbooksPrice: Decimal? {
        get {
            let value = UserDefaults.standard.double(forKey: quickbooksPriceKey)
            return value > 0 ? Decimal(value) : nil
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(NSDecimalNumber(decimal: newValue).doubleValue, forKey: quickbooksPriceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: quickbooksPriceKey)
            }
        }
    }
    
    // QuickBooks cost
    var quickbooksCost: Decimal {
        get {
            let value = UserDefaults.standard.double(forKey: quickbooksCostKey)
            return Decimal(value)
        }
        set {
            UserDefaults.standard.set(NSDecimalNumber(decimal: newValue).doubleValue, forKey: quickbooksCostKey)
        }
    }
    
    // Selling Price (manual override or best available)
    var sellingPrice: Decimal? {
        get {
            // Priority: Manual > Shopify > QuickBooks
            let manualValue = UserDefaults.standard.double(forKey: sellingPriceKey)
            if manualValue > 0 {
                return Decimal(manualValue)
            }
            
            // Try Shopify price
            if let shopifyPrice = shopifyPrice {
                return shopifyPrice
            }
            
            // Fall back to QuickBooks price
            return quickbooksPrice
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(NSDecimalNumber(decimal: newValue).doubleValue, forKey: sellingPriceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sellingPriceKey)
            }
        }
    }
    
    // Get price source for display
    var priceSource: String? {
        let manualValue = UserDefaults.standard.double(forKey: sellingPriceKey)
        if manualValue > 0 {
            return "Manual"
        }
        if shopifyPrice != nil {
            return "Shopify"
        }
        if quickbooksPrice != nil {
            return "QuickBooks"
        }
        return nil
    }
    
    // MARK: - Notes & Tags Properties
    
    var notes: [ProductNote] {
        get {
            guard let data = UserDefaults.standard.data(forKey: notesKey),
                  let decoded = try? JSONDecoder().decode([ProductNote].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: notesKey)
            }
        }
    }
    
    func addNote(_ text: String) {
        var currentNotes = notes
        let newNote = ProductNote(text: text)
        currentNotes.insert(newNote, at: 0)
        notes = currentNotes
    }
    
    func removeNote(_ note: ProductNote) {
        notes = notes.filter { $0.id != note.id }
    }
    
    var tags: [ProductTag] {
        get {
            guard let data = UserDefaults.standard.data(forKey: tagsKey),
                  let decoded = try? JSONDecoder().decode([ProductTag].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: tagsKey)
            }
        }
    }
    
    func addTag(_ tag: ProductTag) {
        var currentTags = tags
        guard !currentTags.contains(where: { $0.id == tag.id }) else {
            return
        }
        currentTags.append(tag)
        tags = currentTags
    }
    
    func removeTag(_ tag: ProductTag) {
        tags = tags.filter { $0.id != tag.id }
    }
    
    // MARK: - Item Sources
    
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
// MARK: - ProductNote Model

struct ProductNote: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var text: String
    var createdDate: Date
    var userName: String
    
    init(id: UUID = UUID(), text: String, createdDate: Date = Date(), userName: String = "User") {
        self.id = id
        self.text = text
        self.createdDate = createdDate
        self.userName = userName
    }
}

// MARK: - ProductTag Model

struct ProductTag: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var name: String
    var color: TagColor
    var createdDate: Date
    
    init(id: UUID = UUID(), name: String, color: TagColor = .blue, createdDate: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.createdDate = createdDate
    }
    
    static let defaultTags: [ProductTag] = [
        ProductTag(name: "High Priority", color: .red),
        ProductTag(name: "Seasonal", color: .orange),
        ProductTag(name: "Fast Mover", color: .green),
        ProductTag(name: "Clearance", color: .purple),
        ProductTag(name: "New Arrival", color: .blue),
        ProductTag(name: "Discontinued", color: .gray)
    ]
}

enum TagColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }
}

// MARK: - Tag Manager

class TagManager: ObservableObject {
    static let shared = TagManager()
    
    @Published var availableTags: [ProductTag] = []
    
    private let userDefaultsKey = "app_available_tags"
    
    init() {
        loadTags()
    }
    
    func loadTags() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ProductTag].self, from: data) {
            availableTags = decoded
        } else {
            availableTags = ProductTag.defaultTags
            saveTags()
        }
    }
    
    func saveTags() {
        if let encoded = try? JSONEncoder().encode(availableTags) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func addTag(_ tag: ProductTag) {
        guard !availableTags.contains(where: { $0.name.lowercased() == tag.name.lowercased() }) else {
            return
        }
        availableTags.append(tag)
        saveTags()
    }
    
    func removeTag(_ tag: ProductTag) {
        availableTags.removeAll { $0.id == tag.id }
        saveTags()
    }
    
    func updateTag(_ tag: ProductTag) {
        if let index = availableTags.firstIndex(where: { $0.id == tag.id }) {
            availableTags[index] = tag
            saveTags()
        }
    }
}

