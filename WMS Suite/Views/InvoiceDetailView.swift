//
//  InvoiceDetailView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/24/25.
//


import SwiftUI
import CoreData

struct InvoiceDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // TODO: Replace with actual Invoice entity
    // @ObservedObject var invoice: Invoice
    
    // Temporary placeholder data
    let invoiceNumber: String = "INV-1234"
    let customerName: String = "John Doe"
    let invoiceDate: Date = Date()
    let dueDate: Date = Date().addingTimeInterval(86400 * 30)
    let status: String = "Unpaid"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Invoice Header
                invoiceHeaderSection
                
                // Customer Info
                customerInfoSection
                
                // Line Items
                lineItemsSection
                
                // Totals
                totalsSection
                
                // Payment History (if any)
                paymentHistorySection
                
                // Notes (if any)
                notesSection
            }
            .padding()
        }
        .navigationTitle(invoiceNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { /* TODO: Share invoice */ }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { /* TODO: Mark as paid */ }) {
                        Label("Mark as Paid", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: { /* TODO: Send reminder */ }) {
                        Label("Send Reminder", systemImage: "bell")
                    }
                    
                    Divider()
                    
                    Button(action: { /* TODO: Open in QuickBooks */ }) {
                        Label("View in QuickBooks", systemImage: "arrow.up.forward.app")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    // MARK: - Invoice Header Section
    
    private var invoiceHeaderSection: some View {
        VStack(spacing: 16) {
            // Status Badge
            HStack {
                Spacer()
                
                Text(status)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(20)
                
                Spacer()
            }
            
            // Amount
            VStack(spacing: 4) {
                Text("Total Amount")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("$1,250.00") // TODO: Wire up actual amount
                    .font(.system(size: 40, weight: .bold))
            }
            
            // Dates
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("Invoice Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(invoiceDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 4) {
                    Text("Due Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isOverdue ? .red : .primary)
                }
            }
            
            if isOverdue {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Overdue by \(daysOverdue) days")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Customer Info Section
    
    private var customerInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customer")
                .font(.headline)
            
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(customerName)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    // TODO: Add customer email/phone if available
                    Text("customer@example.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { /* TODO: Navigate to customer */ }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Line Items Section
    
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.headline)
            
            VStack(spacing: 8) {
                // TODO: Loop through invoice.lineItems
                ForEach(0..<3, id: \.self) { index in
                    InvoiceLineItemRow(
                        description: "Service Item \(index + 1)",
                        quantity: index + 1,
                        unitPrice: Decimal(string: "100.00") ?? 0,
                        total: Decimal(string: "\((index + 1) * 100)") ?? 0
                    )
                    
                    if index < 2 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Totals Section
    
    private var totalsSection: some View {
        VStack(spacing: 12) {
            TotalRow(label: "Subtotal", amount: Decimal(string: "1200.00") ?? 0)
            TotalRow(label: "Tax (4.167%)", amount: Decimal(string: "50.00") ?? 0)
            
            Divider()
            
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text("$1,250.00") // TODO: Wire up actual total
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            if status != "Paid" {
                HStack {
                    Text("Amount Due")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$1,250.00") // TODO: Wire up actual balance
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Payment History Section
    
    private var paymentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment History")
                .font(.headline)
            
            // TODO: Replace with actual payment data
            if true { // Will be: invoice.payments.isEmpty
                VStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No payments recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    // TODO: Loop through payments
                    PaymentRow(
                        date: Date(),
                        amount: Decimal(string: "500.00") ?? 0,
                        method: "Credit Card"
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
            
            // TODO: Wire up actual notes
            Text("Payment terms: Net 30")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        switch status {
        case "Paid": return .green
        case "Unpaid": return isOverdue ? .red : .orange
        case "Partial": return .yellow
        default: return .gray
        }
    }
    
    private var isOverdue: Bool {
        status != "Paid" && dueDate < Date()
    }
    
    private var daysOverdue: Int {
        guard isOverdue else { return 0 }
        return Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
    }
}

// MARK: - Line Item Row Component

struct InvoiceLineItemRow: View {
    let description: String
    let quantity: Int
    let unitPrice: Decimal
    let total: Decimal
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(description)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("\(quantity) × \(unitPrice as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(total as NSDecimalNumber, formatter: currencyFormatter)
                    .font(.body)
                    .fontWeight(.semibold)
            }
        }
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }
}

// MARK: - Total Row Component

struct TotalRow: View {
    let label: String
    let amount: Decimal
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(amount as NSDecimalNumber, formatter: currencyFormatter)
                .font(.subheadline)
        }
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }
}

// MARK: - Payment Row Component

struct PaymentRow: View {
    let date: Date
    let amount: Decimal
    let method: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(method)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(amount as NSDecimalNumber, formatter: currencyFormatter)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }
}

// MARK: - Preview

struct InvoiceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            InvoiceDetailView()
        }
    }
}
