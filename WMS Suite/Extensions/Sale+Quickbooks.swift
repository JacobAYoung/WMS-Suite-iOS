//
//  Sale+QuickBooks.swift (CORRECTED)
//  WMS Suite
//
//  QuickBooks invoice-specific extensions for Sale
//  FIXED: NSDecimalNumber comparison errors
//

import Foundation
import CoreData
import SwiftUI

extension Sale {
    
    // MARK: - QuickBooks Invoice Properties
    
    /// Check if this is a QuickBooks invoice
    var isQuickBooksInvoice: Bool {
        source == "quickbooks"
    }
    
    /// Check if synced with QuickBooks
    var isSyncedWithQuickBooks: Bool {
        quickbooksInvoiceId != nil && !(quickbooksInvoiceId?.isEmpty ?? true)
    }
    
    /// Get payment status enum
    var paymentStatusEnum: PaymentStatus? {
        guard let status = paymentStatus else { return nil }
        return PaymentStatus(rawValue: status)
    }
    
    /// Set payment status from enum
    func setPaymentStatus(_ status: PaymentStatus) {
        self.paymentStatus = status.rawValue
    }
    
    /// Calculate actual payment status based on data
    var calculatedPaymentStatus: PaymentStatus {
        PaymentStatus.determine(
            totalAmount: totalAmount ?? NSDecimalNumber.zero,
            amountPaid: amountPaid ?? NSDecimalNumber.zero,
            dueDate: paymentDueDate
        )
    }
    
    /// Get remaining balance
    var remainingBalance: NSDecimalNumber {
        let total = totalAmount ?? NSDecimalNumber.zero
        let paid = amountPaid ?? NSDecimalNumber.zero
        return total.subtracting(paid)
    }
    
    /// Get formatted remaining balance
    var formattedRemainingBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: remainingBalance) ?? "$0.00"
    }
    
    /// Get formatted amount paid
    var formattedAmountPaid: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: amountPaid ?? NSDecimalNumber.zero) ?? "$0.00"
    }
    
    /// Check if invoice is overdue
    var isOverdue: Bool {
        guard let dueDate = paymentDueDate else { return false }
        return dueDate < Date() && remainingBalance.doubleValue > 0
    }
    
    /// Get days until due (negative if overdue)
    var daysUntilDue: Int? {
        guard let dueDate = paymentDueDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day
        return days
    }
    
    /// Get formatted due date string
    var formattedDueDate: String? {
        guard let dueDate = paymentDueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dueDate)
    }
    
    /// Get due date status text
    var dueDateStatusText: String? {
        guard let days = daysUntilDue else { return nil }
        
        if days < 0 {
            return "Overdue by \(abs(days)) days"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else if days <= 7 {
            return "Due in \(days) days"
        } else {
            return formattedDueDate
        }
    }
    
    /// Get payment progress percentage (0-1)
    var paymentProgress: Double {
        let total = totalAmount?.doubleValue ?? 0
        let paid = amountPaid?.doubleValue ?? 0
        guard total > 0 else { return 0 }
        return min(paid / total, 1.0)
    }
    
    // MARK: - Invoice Display Helpers
    
    /// Get invoice number (use orderNumber for QuickBooks invoices)
    var invoiceNumber: String? {
        isQuickBooksInvoice ? orderNumber : nil
    }
    
    /// Get formatted total amount
    var formattedTotalAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: totalAmount ?? NSDecimalNumber.zero) ?? "$0.00"
    }
    
    /// Get payment status color
    var paymentStatusColor: Color {
        calculatedPaymentStatus.color
    }
    
    /// Get payment status icon
    var paymentStatusIcon: String {
        calculatedPaymentStatus.icon
    }
    
    /// Get payment status display name
    var paymentStatusDisplayName: String {
        calculatedPaymentStatus.displayName
    }
    
    // MARK: - Customer Relationship
    
    /// Get customer name safely
    var customerName: String {
        customer?.displayName ?? "Unknown Customer"
    }
    
    /// Check if has linked customer
    var hasCustomer: Bool {
        customer != nil
    }
    
    // MARK: - QuickBooks Sync Helpers
    
    /// Update from QuickBooks invoice data
    func updateFromQuickBooksInvoice(
        qbInvoiceId: String,
        orderNumber: String,
        date: Date,
        totalAmount: NSDecimalNumber,
        amountPaid: NSDecimalNumber,
        dueDate: Date?,
        customerId: String?
    ) {
        self.quickbooksInvoiceId = qbInvoiceId
        self.orderNumber = orderNumber
        self.saleDate = date
        self.totalAmount = totalAmount
        self.amountPaid = amountPaid
        self.paymentDueDate = dueDate
        self.source = "quickbooks"
        
        // Update payment status
        let status = PaymentStatus.determine(
            totalAmount: totalAmount,
            amountPaid: amountPaid,
            dueDate: dueDate
        )
        self.paymentStatus = status.rawValue
        
        // Auto-flag overdue as priority
        if status == .overdue {
            self.isPriority = true
            self.needsAttention = true
        }
        
        self.lastSyncedQuickbooksDate = Date()
    }
    
    /// Mark invoice as paid (FIXED: NSDecimalNumber comparison)
    func markAsPaid(amount: NSDecimalNumber? = nil) {
        let paymentAmount = amount ?? (totalAmount ?? NSDecimalNumber.zero)
        self.amountPaid = paymentAmount
        self.paymentStatus = PaymentStatus.paid.rawValue
        
        // Remove priority flags when fully paid
        // FIXED: Use NSDecimalNumber.compare() instead of >=
        let total = totalAmount ?? NSDecimalNumber.zero
        if paymentAmount.compare(total) != .orderedAscending {  // paymentAmount >= total
            self.isPriority = false
            self.needsAttention = false
        }
    }
    
    /// Record partial payment
    func recordPartialPayment(amount: NSDecimalNumber) {
        let currentPaid = self.amountPaid ?? NSDecimalNumber.zero
        let newTotal = currentPaid.adding(amount)
        self.amountPaid = newTotal
        
        // Update status
        let status = PaymentStatus.determine(
            totalAmount: totalAmount ?? NSDecimalNumber.zero,
            amountPaid: newTotal,
            dueDate: paymentDueDate
        )
        self.paymentStatus = status.rawValue
    }
    
    /// Check if sync is stale (> 24 hours)
    var needsQuickBooksSync: Bool {
        guard let lastSync = lastSyncedQuickbooksDate else { return true }
        return Date().timeIntervalSince(lastSync) > 86400 // 24 hours
    }
}
