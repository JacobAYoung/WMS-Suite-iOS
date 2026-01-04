//
//  ReorderRecommendation.swift
//  WMS Suite
//
//  Model for smart reorder recommendations
//

import Foundation
import SwiftUI

// MARK: - Reorder Recommendation Model

struct ReorderRecommendation: Identifiable {
    let id = UUID()
    let item: InventoryItem
    let reason: ReorderReason
    let priority: ReorderPriority
    let currentStock: Decimal
    let recommendedOrderQuantity: Decimal
    let estimatedStockoutDate: Date?
    let averageDailySales: Double
    let daysOfStockRemaining: Int
    
    var urgencyScore: Int {
        priority.rawValue * 10 + (7 - daysOfStockRemaining)
    }
}

// MARK: - Reorder Reason

enum ReorderReason: String {
    case belowMinimum = "Below Minimum Stock Level"
    case nearStockout = "Trending Toward Stockout"
    case highVelocity = "High Sales Velocity"
    case outOfStock = "Out of Stock"
    
    var icon: String {
        switch self {
        case .belowMinimum:
            return "exclamationmark.triangle.fill"
        case .nearStockout:
            return "clock.fill"
        case .highVelocity:
            return "chart.line.uptrend.xyaxis"
        case .outOfStock:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .belowMinimum:
            return .orange
        case .nearStockout:
            return .yellow
        case .highVelocity:
            return .blue
        case .outOfStock:
            return .red
        }
    }
}

// MARK: - Reorder Priority

enum ReorderPriority: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    static func < (lhs: ReorderPriority, rhs: ReorderPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Reorder Recommendation Service

class ReorderRecommendationService {
    
    /// Generate reorder recommendations based on inventory and sales data
    static func generateRecommendations(
        for items: [InventoryItem],
        salesHistory: [String: [SalesHistoryDisplay]] = [:],
        leadTimeDays: Int = 7
    ) -> [ReorderRecommendation] {
        var recommendations: [ReorderRecommendation] = []
        
        for item in items {
            if let recommendation = analyzeItem(item, salesHistory: salesHistory[item.sku ?? ""] ?? [], leadTimeDays: leadTimeDays) {
                recommendations.append(recommendation)
            }
        }
        
        // Sort by urgency (priority first, then days remaining)
        return recommendations.sorted { $0.urgencyScore > $1.urgencyScore }
    }
    
    // MARK: - Analysis Methods
    
    private static func analyzeItem(
        _ item: InventoryItem,
        salesHistory: [SalesHistoryDisplay],
        leadTimeDays: Int
    ) -> ReorderRecommendation? {
        
        // Convert NSDecimalNumber? to Decimal safely
        let currentStock: Decimal
        if let decimalNumber = item.quantity as? NSDecimalNumber {
            currentStock = decimalNumber.decimalValue
        } else if let decimal = item.quantity as? Decimal {
            currentStock = decimal
        } else {
            currentStock = 0
        }
        
        let minStockLevel: Decimal
        if let decimalNumber = item.minStockLevel as? NSDecimalNumber {
            minStockLevel = decimalNumber.decimalValue
        } else if let decimal = item.minStockLevel as? Decimal {
            minStockLevel = decimal
        } else {
            minStockLevel = 0
        }
        
        // Calculate sales velocity
        let averageDailySales = calculateAverageDailySales(from: salesHistory)
        
        // Check for out of stock
        if currentStock == 0 {
            return ReorderRecommendation(
                item: item,
                reason: .outOfStock,
                priority: .critical,
                currentStock: currentStock,
                recommendedOrderQuantity: max(minStockLevel, Decimal(averageDailySales * Double(leadTimeDays * 2))),
                estimatedStockoutDate: Date(), // Already out
                averageDailySales: averageDailySales,
                daysOfStockRemaining: 0
            )
        }
        
        // Check if below minimum stock level
        if currentStock < minStockLevel && minStockLevel > 0 {
            let daysRemaining = averageDailySales > 0 ? Int(NSDecimalNumber(decimal: currentStock).doubleValue / averageDailySales) : 999
            let priority = determinePriority(daysRemaining: daysRemaining)
            
            return ReorderRecommendation(
                item: item,
                reason: .belowMinimum,
                priority: priority,
                currentStock: currentStock,
                recommendedOrderQuantity: max(minStockLevel - currentStock, Decimal(averageDailySales * Double(leadTimeDays))),
                estimatedStockoutDate: calculateStockoutDate(currentStock: currentStock, averageDailySales: averageDailySales),
                averageDailySales: averageDailySales,
                daysOfStockRemaining: daysRemaining
            )
        }
        
        // Check for near stockout based on sales velocity
        if averageDailySales > 0 {
            let daysRemaining = Int(NSDecimalNumber(decimal: currentStock).doubleValue / averageDailySales)
            
            // Alert if stock will run out within lead time
            if daysRemaining <= leadTimeDays {
                let priority = determinePriority(daysRemaining: daysRemaining)
                
                return ReorderRecommendation(
                    item: item,
                    reason: .nearStockout,
                    priority: priority,
                    currentStock: currentStock,
                    recommendedOrderQuantity: Decimal(averageDailySales * Double(leadTimeDays * 2)), // Order for 2x lead time
                    estimatedStockoutDate: calculateStockoutDate(currentStock: currentStock, averageDailySales: averageDailySales),
                    averageDailySales: averageDailySales,
                    daysOfStockRemaining: daysRemaining
                )
            }
            
            // Check for high velocity items (selling > 5 per day on average)
            if averageDailySales >= 5.0 && daysRemaining <= leadTimeDays * 2 {
                return ReorderRecommendation(
                    item: item,
                    reason: .highVelocity,
                    priority: .medium,
                    currentStock: currentStock,
                    recommendedOrderQuantity: Decimal(averageDailySales * Double(leadTimeDays * 3)), // Order for 3x lead time
                    estimatedStockoutDate: calculateStockoutDate(currentStock: currentStock, averageDailySales: averageDailySales),
                    averageDailySales: averageDailySales,
                    daysOfStockRemaining: daysRemaining
                )
            }
        }
        
        return nil
    }
    
    private static func calculateAverageDailySales(from salesHistory: [SalesHistoryDisplay]) -> Double {
        guard !salesHistory.isEmpty else { return 0.0 }
        
        let totalSold = salesHistory.reduce(0) { $0 + Int($1.quantity) }
        return Double(totalSold) / Double(salesHistory.count)
    }
    
    private static func calculateStockoutDate(currentStock: Int32, averageDailySales: Double) -> Date? {
        guard averageDailySales > 0 else { return nil }
        
        let daysRemaining = Double(currentStock) / averageDailySales
        return Calendar.current.date(byAdding: .day, value: Int(daysRemaining), to: Date())
    }
    
    private static func determinePriority(daysRemaining: Int) -> ReorderPriority {
        switch daysRemaining {
        case 0:
            return .critical
        case 1...3:
            return .high
        case 4...7:
            return .medium
        default:
            return .low
        }
    }
}
