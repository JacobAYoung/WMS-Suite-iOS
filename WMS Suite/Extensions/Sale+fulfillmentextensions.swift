//
//  Sale+fulfillmentextensions.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/19/25.
//

import Foundation
import CoreData

extension Sale {
    
    // MARK: - Fulfillment Status
    
    /// Get fulfillment status as enum (handles nil gracefully)
    var fulfillmentStatusEnum: OrderFulfillmentStatus? {
        guard let statusString = fulfillmentStatus else { return nil }
        return OrderFulfillmentStatus(rawValue: statusString)
    }
    
    /// Set fulfillment status from enum
    func setFulfillmentStatus(_ status: OrderFulfillmentStatus) {
        fulfillmentStatus = status.rawValue
    }
    
    // MARK: - Status Helpers
    
    /// Check if order needs fulfillment (not yet shipped)
    var needsFulfillment: Bool {
        return fulfillmentStatusEnum == .needsFulfillment || fulfillmentStatusEnum == nil
    }
    
    /// Check if order is in transit
    var isInTransit: Bool {
        return fulfillmentStatusEnum == .inTransit
    }
    
    /// Check if order is delivered
    var isDelivered: Bool {
        return fulfillmentStatusEnum == .delivered
    }
    
    /// Check if tracking is unconfirmed (shipped >14 days, no delivery)
    var isUnconfirmed: Bool {
        if fulfillmentStatusEnum == .unconfirmed {
            return true
        }
        
        // Auto-detect unconfirmed: shipped >14 days ago, still in transit
        guard let shipped = shippedDate,
              isInTransit else {
            return false
        }
        
        let daysSinceShipping = Calendar.current.dateComponents([.day], from: shipped, to: Date()).day ?? 0
        let threshold = UserDefaults.standard.integer(forKey: "unconfirmedOrderThreshold")
        let daysThreshold = threshold > 0 ? threshold : 14 // Default 14 days
        
        return daysSinceShipping > daysThreshold
    }
    
    // MARK: - Tracking Info
    
    /// Get formatted tracking display text
    var trackingDisplayText: String? {
        guard let tracking = trackingNumber, !tracking.isEmpty else {
            return nil
        }
        
        if let carrier = carrier, !carrier.isEmpty {
            return "\(carrier): \(tracking)"
        }
        
        return tracking
    }
    
    /// Get days since shipped
    var daysSinceShipped: Int? {
        guard let shipped = shippedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: shipped, to: Date()).day
    }
    
    /// Get expected delivery date (estimate: shipped date + 7 days if no tracking update)
    var estimatedDeliveryDate: Date? {
        guard let shipped = shippedDate else { return nil }
        
        // If we have a tracking update, use that + 3 days
        if let lastUpdate = lastTrackingUpdate {
            return Calendar.current.date(byAdding: .day, value: 3, to: lastUpdate)
        }
        
        // Otherwise, shipped date + 7 days
        return Calendar.current.date(byAdding: .day, value: 7, to: shipped)
    }
    
    // MARK: - Priority/Attention
    
    /// Check if order has any flags (priority or needs attention)
    var hasFlagsSet: Bool {
        return isPriority || needsAttention
    }
    
    /// Get notes array (sorted by date, newest first)
    var notesArray: [OrderNote] {
        guard let noteSet = notes as? Set<OrderNote> else { return [] }
        return Array(noteSet).sorted { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
    }
    
    /// Add a note to this order
    func addNote(text: String, type: String, userName: String?, context: NSManagedObjectContext) {
        let note = OrderNote(context: context)
        note.id = Int32(Date().timeIntervalSince1970)
        note.noteText = text
        note.createdDate = Date()
        note.noteType = type
        note.userName = userName
        note.sale = self
    }
    
    // MARK: - Fetch Helpers
    
    /// Fetch orders by fulfillment status
    static func fetchOrders(byStatus status: OrderFulfillmentStatus, context: NSManagedObjectContext) -> [Sale] {
        let request = NSFetchRequest<Sale>(entityName: "Sale")
        request.predicate = NSPredicate(format: "fulfillmentStatus == %@", status.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
    
    /// Fetch priority orders
    static func fetchPriorityOrders(context: NSManagedObjectContext) -> [Sale] {
        let request = NSFetchRequest<Sale>(entityName: "Sale")
        request.predicate = NSPredicate(format: "isPriority == YES OR needsAttention == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
}
