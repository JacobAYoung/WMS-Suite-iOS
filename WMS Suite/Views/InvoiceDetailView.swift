//
//  InvoiceDetailView.swift (CONFLICT-FREE VERSION)
//  WMS Suite
//
//  Detailed view of a single QuickBooks invoice
//

import SwiftUI
import CoreData

struct InvoiceDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var invoice: Sale
    
    var lineItemsArray: [SaleLineItem] {
        guard let items = invoice.lineItems as? Set<SaleLineItem> else { return [] }
        return Array(items).sorted { ($0.item?.name ?? "") < ($1.item?.name ?? "") }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Invoice Header
                invoiceHeaderSection
                
                // Customer Info
                if invoice.hasCustomer {
                    customerInfoSection
                }
                
                // Line Items
                if !lineItemsArray.isEmpty {
                    lineItemsSection
                }
                
                // Totals
                totalsSection
                
                // Notes (if any)
                if invoice.hasMemo {
                    notesSection
                }
            }
            .padding()
        }
        .navigationTitle(invoice.orderNumber ?? "Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { /* TODO: Share */ }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(action: { /* TODO: Open in QB */ }) {
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
                
                Text(invoice.paymentStatusDisplayName)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(invoice.paymentStatusColor.opacity(0.2))
                    .foregroundColor(invoice.paymentStatusColor)
                    .cornerRadius(20)
                
                Spacer()
            }
            
            // Amount
            VStack(spacing: 4) {
                Text("Total Amount")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(invoice.formattedTotalAmount)
                    .font(.system(size: 40, weight: .bold))
            }
            
            // Dates
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("Invoice Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let date = invoice.saleDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("Due Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let dueDate = invoice.paymentDueDate {
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(invoice.isOverdue ? .red : .primary)
                    } else {
                        Text("—")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Overdue warning
            if invoice.isOverdue, let days = invoice.daysUntilDue {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Overdue by \(abs(days)) days")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Payment terms
            if let terms = invoice.invoiceTerms {
                Text("Terms: \(terms)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    Text(invoice.customerName)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    if let email = invoice.customer?.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let customer = invoice.customer {
                    NavigationLink(destination: CustomerDetailView(customer: customer)) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                    }
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
                ForEach(lineItemsArray, id: \.id) { lineItem in
                    InvoiceLineItemRow(lineItem: lineItem)
                    
                    if lineItem != lineItemsArray.last {
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
            TotalRow(label: "Subtotal", amount: invoice.formattedSubtotal)
            TotalRow(label: "Tax (\(invoice.formattedTaxRate))", amount: invoice.formattedTaxAmount)
            
            Divider()
            
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(invoice.formattedTotalAmount)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            if invoice.paymentStatus != "paid" {
                HStack {
                    Text("Amount Due")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(invoice.formattedRemainingBalance)
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            } else {
                HStack {
                    Text("Amount Paid")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(invoice.formattedAmountPaid)
                        .font(.headline)
                        .foregroundColor(.green)
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
            
            Text(invoice.invoiceMemo ?? "")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Invoice Line Item Row Component (RENAMED to avoid conflict with AddSalesView.swift)

struct InvoiceLineItemRow: View {
    let lineItem: SaleLineItem
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lineItem.item?.name ?? "Item")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    let qtyString = InventoryItem.formatQuantity(lineItem.quantity)
                    let price = lineItem.unitPrice ?? NSDecimalNumber.zero
                    Text("\(qtyString) × \(price as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(lineItem.lineTotal ?? NSDecimalNumber.zero, formatter: currencyFormatter)
                    .font(.body)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Total Row Component

struct TotalRow: View {
    let label: String
    let amount: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(amount)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

struct InvoiceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Text("Invoice Detail Preview")
        }
    }
}
