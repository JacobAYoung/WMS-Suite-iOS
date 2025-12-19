//
//  OrderSource.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
//

import SwiftUI

enum OrderSource: String, CaseIterable, Identifiable {
    case local = "local"
    case shopify = "shopify"
    case quickbooks = "quickbooks"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .local:
            return "Local"
        case .shopify:
            return "Shopify"
        case .quickbooks:
            return "QuickBooks"
        }
    }
    
    var icon: String {
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
