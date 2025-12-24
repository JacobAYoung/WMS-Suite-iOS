//
//  CustomerNoteType.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/23/25.
//

import Foundation
import SwiftUI

enum CustomerNoteType: String, CaseIterable, Identifiable {
    case general = "general"
    case payment = "payment"
    case delivery = "delivery"
    case service = "service"
    case followUp = "follow_up"
    case complaint = "complaint"
    case preference = "preference"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .payment: return "Payment"
        case .delivery: return "Delivery"
        case .service: return "Service"
        case .followUp: return "Follow-up"
        case .complaint: return "Complaint"
        case .preference: return "Preference"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "note.text"
        case .payment: return "dollarsign.circle"
        case .delivery: return "shippingbox"
        case .service: return "wrench.and.screwdriver"
        case .followUp: return "calendar.badge.clock"
        case .complaint: return "exclamationmark.bubble"
        case .preference: return "star"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .payment: return .green
        case .delivery: return .blue
        case .service: return .orange
        case .followUp: return .purple
        case .complaint: return .red
        case .preference: return .yellow
        }
    }
}
