//
//  SalesHistoryDisplay.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/16/25.
//

import Foundation

/// Helper struct for displaying sales history
/// Used to display sales data across different views
struct SalesHistoryDisplay: Identifiable {
    let id = UUID()
    let saleDate: Date?
    let orderNumber: String?
    let quantity: Int32
}
