//
//  InventoryItem+Display.swift
//  WMS Suite
//
//  Display helpers for InventoryItem quantities and units of measure
//

import Foundation

extension InventoryItem {
    /// Formatted quantity with unit of measure
    var quantityDisplay: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let qtyString = formatter.string(from: NSDecimalNumber(decimal: quantity)) ?? "\(quantity)"
        let unit = unitOfMeasure ?? "pcs"
        return "\(qtyString) \(unit)"
    }
    
    /// Short unit display (for constrained spaces)
    var unitAbbreviation: String {
        guard let unit = unitOfMeasure?.lowercased() else { return "pcs" }
        
        switch unit {
        case "pieces": return "pcs"
        case "feet": return "ft"
        case "meters": return "m"
        case "yards": return "yd"
        case "pounds": return "lbs"
        case "kilograms": return "kg"
        case "gallons": return "gal"
        case "liters": return "L"
        case "inches": return "in"
        case "centimeters": return "cm"
        case "ounces": return "oz"
        case "grams": return "g"
        default: return unit
        }
    }
    
    /// Format a quantity value
    static func formatQuantity(_ qty: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: qty)) ?? "\(qty)"
    }
}
