//
//  ForecastResult.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation

struct ForecastResult {
    let item: InventoryItem
    let averageDailySales: Double
    let projectedSales: Int
    let daysUntilStockout: Int
    let recommendedOrderQuantity: Int
}
