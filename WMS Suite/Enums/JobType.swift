//
//  JobType.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI

enum JobType: String, CaseIterable, Identifiable {
    case service = "service"
    case delivery = "delivery"
    case meeting = "meeting"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .service:
            return "Service Appointment"
        case .delivery:
            return "Delivery/Pickup"
        case .meeting:
            return "Customer Meeting"
        case .other:
            return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .service:
            return "wrench.and.screwdriver"
        case .delivery:
            return "shippingbox"
        case .meeting:
            return "person.2"
        case .other:
            return "ellipsis.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .service:
            return .blue
        case .delivery:
            return .orange
        case .meeting:
            return .green
        case .other:
            return .gray
        }
    }
}
