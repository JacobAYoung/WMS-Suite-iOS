//
//  PaymentStatus.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/23/25.
//

import Foundation
import SwiftUI

enum PaymentStatus: String, CaseIterable, Identifiable {
    case unpaid = "unpaid"
    case partial = "partial"
    case paid = "paid"
    case overdue = "overdue"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .unpaid: return "Unpaid"
        case .partial: return "Partially Paid"
        case .paid: return "Paid"
        case .overdue: return "Overdue"
        }
    }
    
    var icon: String {
        switch self {
        case .unpaid: return "dollarsign.circle"
        case .partial: return "dollarsign.circle.fill"
        case .paid: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .unpaid: return .orange
        case .partial: return .yellow
        case .paid: return .green
        case .overdue: return .red
        }
    }
    
    /// Determine payment status based on amounts and due date
    static func determine(totalAmount: NSDecimalNumber, amountPaid: NSDecimalNumber, dueDate: Date?) -> PaymentStatus {
        let total = totalAmount.doubleValue
        let paid = amountPaid.doubleValue
        
        // Fully paid
        if paid >= total {
            return .paid
        }
        
        // Partially paid
        if paid > 0 {
            return .partial
        }
        
        // Check if overdue
        if let dueDate = dueDate, dueDate < Date() {
            return .overdue
        }
        
        // Unpaid
        return .unpaid
    }
}
