//
//  ProfitMarginAnalysis.swift
//  WMS Suite
//
//  Models and services for profit margin analysis
//

import Foundation
import SwiftUI

// MARK: - Profit Margin Models

struct ProductMarginAnalysis: Identifiable {
    let id = UUID()
    let item: InventoryItem
    let cost: Decimal
    let sellingPrice: Decimal
    let margin: Decimal
    let profitPerUnit: Decimal
    let totalInventoryProfit: Decimal
    
    var marginPercentage: Double {
        NSDecimalNumber(decimal: margin).doubleValue
    }
    
    var marginCategory: MarginCategory {
        if margin < 0 {
            return .negative
        } else if margin < 10 {
            return .veryLow
        } else if margin < 20 {
            return .low
        } else if margin < 40 {
            return .good
        } else {
            return .excellent
        }
    }
}

enum MarginCategory: String, CaseIterable {
    case negative = "Negative"
    case veryLow = "Very Low"
    case low = "Low"
    case good = "Good"
    case excellent = "Excellent"
    
    var color: Color {
        switch self {
        case .negative:
            return .red
        case .veryLow:
            return .orange
        case .low:
            return .yellow
        case .good:
            return .green
        case .excellent:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .negative:
            return "exclamationmark.triangle.fill"
        case .veryLow:
            return "arrow.down.circle.fill"
        case .low:
            return "minus.circle.fill"
        case .good:
            return "checkmark.circle.fill"
        case .excellent:
            return "star.fill"
        }
    }
    
    var range: String {
        switch self {
        case .negative:
            return "< 0%"
        case .veryLow:
            return "0-10%"
        case .low:
            return "10-20%"
        case .good:
            return "20-40%"
        case .excellent:
            return "> 40%"
        }
    }
}

// MARK: - Margin Summary

struct MarginSummary {
    let totalProducts: Int
    let productsWithPricing: Int
    let averageMargin: Decimal
    let totalInventoryValue: Decimal
    let totalPotentialProfit: Decimal
    let negativeMarginCount: Int
    let lowMarginCount: Int
    
    var pricingCoverage: Double {
        guard totalProducts > 0 else { return 0 }
        return Double(productsWithPricing) / Double(totalProducts) * 100
    }
}

// MARK: - Profit Margin Service

class ProfitMarginService {
    
    /// Analyze all products for margin insights
    static func analyzeProducts(_ items: [InventoryItem]) -> [ProductMarginAnalysis] {
        var analyses: [ProductMarginAnalysis] = []
        
        for item in items {
            // Only analyze items with both cost and selling price
            guard item.cost > 0, let sellingPrice = item.sellingPrice, sellingPrice > 0 else {
                continue
            }
            
            let profitPerUnit = sellingPrice - item.cost
            let margin = (profitPerUnit / sellingPrice) * 100
            let totalProfit = profitPerUnit * Decimal(item.quantity)
            
            let analysis = ProductMarginAnalysis(
                item: item,
                cost: item.cost,
                sellingPrice: sellingPrice,
                margin: margin,
                profitPerUnit: profitPerUnit,
                totalInventoryProfit: totalProfit
            )
            
            analyses.append(analysis)
        }
        
        return analyses.sorted { $0.margin < $1.margin } // Sort by margin (worst first)
    }
    
    /// Generate summary statistics
    static func generateSummary(from items: [InventoryItem], analyses: [ProductMarginAnalysis]) -> MarginSummary {
        let totalProducts = items.count
        let productsWithPricing = analyses.count
        
        let totalMargin = analyses.reduce(Decimal(0)) { $0 + $1.margin }
        let averageMargin = productsWithPricing > 0 ? totalMargin / Decimal(productsWithPricing) : 0
        
        let totalInventoryValue = analyses.reduce(Decimal(0)) { $0 + ($1.cost * Decimal($1.item.quantity)) }
        let totalPotentialProfit = analyses.reduce(Decimal(0)) { $0 + $1.totalInventoryProfit }
        
        let negativeMarginCount = analyses.filter { $0.margin < 0 }.count
        let lowMarginCount = analyses.filter { $0.margin >= 0 && $0.margin < 20 }.count
        
        return MarginSummary(
            totalProducts: totalProducts,
            productsWithPricing: productsWithPricing,
            averageMargin: averageMargin,
            totalInventoryValue: totalInventoryValue,
            totalPotentialProfit: totalPotentialProfit,
            negativeMarginCount: negativeMarginCount,
            lowMarginCount: lowMarginCount
        )
    }
    
    /// Calculate margin for given cost and price
    static func calculateMargin(cost: Decimal, sellingPrice: Decimal) -> (margin: Decimal, profit: Decimal, markup: Decimal) {
        guard sellingPrice > 0 else {
            return (0, 0, 0)
        }
        
        let profit = sellingPrice - cost
        let margin = (profit / sellingPrice) * 100
        let markup = cost > 0 ? (profit / cost) * 100 : 0
        
        return (margin, profit, markup)
    }
    
    /// Get margin category breakdown
    static func getCategoryBreakdown(_ analyses: [ProductMarginAnalysis]) -> [MarginCategory: Int] {
        var breakdown: [MarginCategory: Int] = [:]
        
        for category in MarginCategory.allCases {
            breakdown[category] = analyses.filter { $0.marginCategory == category }.count
        }
        
        return breakdown
    }
}

// MARK: - Quick Calculator Model

struct QuickCalculation {
    var cost: Decimal = 0
    var sellingPrice: Decimal = 0
    var quantity: Int = 1
    
    var profit: Decimal {
        sellingPrice - cost
    }
    
    var margin: Decimal {
        guard sellingPrice > 0 else { return 0 }
        return ((sellingPrice - cost) / sellingPrice) * 100
    }
    
    var markup: Decimal {
        guard cost > 0 else { return 0 }
        return ((sellingPrice - cost) / cost) * 100
    }
    
    var totalProfit: Decimal {
        profit * Decimal(quantity)
    }
    
    var marginCategory: MarginCategory {
        if margin < 0 {
            return .negative
        } else if margin < 10 {
            return .veryLow
        } else if margin < 20 {
            return .low
        } else if margin < 40 {
            return .good
        } else {
            return .excellent
        }
    }
}
