//
//  OrderFulfillmentStatus.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/19/25.
//

import SwiftUI

enum OrderFulfillmentStatus: String, CaseIterable, Identifiable {
    case needsFulfillment = "needs_fulfillment"
    case inTransit = "in_transit"
    case delivered = "delivered"
    case unconfirmed = "unconfirmed"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .needsFulfillment:
            return "Needs Fulfillment"
        case .inTransit:
            return "In Transit"
        case .delivered:
            return "Delivered"
        case .unconfirmed:
            return "Unconfirmed"
        }
    }
    
    var icon: String {
        switch self {
        case .needsFulfillment:
            return "shippingbox"
        case .inTransit:
            return "truck.box"
        case .delivered:
            return "checkmark.seal"
        case .unconfirmed:
            return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .needsFulfillment:
            return .blue
        case .inTransit:
            return .orange
        case .delivered:
            return .green
        case .unconfirmed:
            return .yellow
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .needsFulfillment:
            return 0
        case .inTransit:
            return 1
        case .unconfirmed:
            return 2
        case .delivered:
            return 3
        }
    }
}
