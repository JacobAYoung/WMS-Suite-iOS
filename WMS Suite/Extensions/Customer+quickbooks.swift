//
//  Customer+QuickBooks.swift
//  WMS Suite
//
//  QuickBooks-specific extensions for Customer
//

import Foundation
import CoreData

extension Customer {
    
    // MARK: - QuickBooks Properties
    
    /// Check if customer is synced with QuickBooks
    var isSyncedWithQuickBooks: Bool {
        quickbooksCustomerId != nil && !(quickbooksCustomerId?.isEmpty ?? true)
    }
    
    /// Get formatted balance for display
    var formattedBalance: String {
        guard let balance = balance else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: balance) ?? "$0.00"
    }
    
    /// Get unpaid invoices for this customer
    var unpaidInvoices: [Sale] {
        guard let salesSet = sales as? Set<Sale> else { return [] }
        return salesSet.filter { sale in
            sale.source == "quickbooks" &&
            (sale.paymentStatus == "unpaid" || sale.paymentStatus == "overdue" || sale.paymentStatus == "partial")
        }.sorted { ($0.saleDate ?? Date.distantPast) > ($1.saleDate ?? Date.distantPast) }
    }
    
    /// Get total unpaid amount
    var totalUnpaidAmount: NSDecimalNumber {
        let total = unpaidInvoices.reduce(NSDecimalNumber.zero) { result, sale in
            let saleAmount = sale.totalAmount ?? NSDecimalNumber.zero
            let paidAmount = sale.amountPaid ?? NSDecimalNumber.zero
            let remaining = saleAmount.subtracting(paidAmount)
            return result.adding(remaining)
        }
        return total
    }
    
    /// Get overdue invoices count
    var overdueInvoicesCount: Int {
        unpaidInvoices.filter { sale in
            sale.paymentStatus == "overdue"
        }.count
    }
    
    /// Check if customer has overdue payments
    var hasOverduePayments: Bool {
        overdueInvoicesCount > 0
    }
    
    // MARK: - Customer Notes
    
    /// Get customer notes array sorted by date
    var customerNotesArray: [CustomerNote] {
        guard let notesSet = customerNotes as? Set<CustomerNote> else { return [] }
        return Array(notesSet).sorted { $0.createdDate > $1.createdDate }
    }
    
    /// Get notes by type
    func notes(ofType type: CustomerNoteType) -> [CustomerNote] {
        customerNotesArray.filter { $0.noteType == type.rawValue }
    }
    
    /// Get recent notes (last 5)
    var recentNotes: [CustomerNote] {
        Array(customerNotesArray.prefix(5))
    }
    
    /// Check if customer has any notes
    var hasNotes: Bool {
        !customerNotesArray.isEmpty
    }
    
    // MARK: - Purchase History
    
    /// Get all sales (orders + invoices) for this customer
    var allSales: [Sale] {
        guard let salesSet = sales as? Set<Sale> else { return [] }
        return salesSet.sorted { ($0.saleDate ?? Date.distantPast) > ($1.saleDate ?? Date.distantPast) }
    }
    
    /// Get QuickBooks invoices only
    var quickbooksInvoices: [Sale] {
        allSales.filter { $0.source == "quickbooks" }
    }
    
    /// Get Shopify orders only
    var shopifyOrders: [Sale] {
        allSales.filter { $0.source == "shopify" }
    }
    
    /// Get local orders only
    var localOrders: [Sale] {
        allSales.filter { $0.source == "local" }
    }
    
    /// Get total purchase amount (all time)
    var totalPurchaseAmount: NSDecimalNumber {
        allSales.reduce(NSDecimalNumber.zero) { result, sale in
            result.adding(sale.totalAmount ?? NSDecimalNumber.zero)
        }
    }
    
    /// Get formatted total purchases
    var formattedTotalPurchases: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: totalPurchaseAmount) ?? "$0.00"
    }
    
    // MARK: - QuickBooks Sync Helpers
    
    /// Update from QuickBooks customer data
    func updateFromQuickBooks(
        qbId: String,
        companyName: String?,
        email: String?,
        phone: String?,
        billingAddress: String?,
        shippingAddress: String?,
        balance: NSDecimalNumber
    ) {
        self.quickbooksCustomerId = qbId
        
        // Only update if not empty
        if let companyName = companyName, !companyName.isEmpty {
            self.companyName = companyName
        }
        
        if let email = email, !email.isEmpty {
            self.email = email
        }
        
        if let phone = phone, !phone.isEmpty {
            self.phone = phone
        }
        
        if let billingAddress = billingAddress, !billingAddress.isEmpty {
            self.billingAddress = billingAddress
        }
        
        if let shippingAddress = shippingAddress, !shippingAddress.isEmpty {
            self.shippingAddress = shippingAddress
        }
        
        self.balance = balance
        self.lastSyncedQuickbooksDate = Date()
    }
    
    /// Check if sync is stale (> 24 hours)
    var needsQuickBooksSync: Bool {
        guard let lastSync = lastSyncedQuickbooksDate else { return true }
        return Date().timeIntervalSince(lastSync) > 86400 // 24 hours
    }
}
