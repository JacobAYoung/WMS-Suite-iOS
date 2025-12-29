//
//  InvoicesListView.swift (CONFLICT-FREE VERSION)
//  WMS Suite
//
//  Full list view of all invoices for a customer
//

import SwiftUI
import CoreData

struct InvoicesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let customer: Customer
    
    @State private var searchText = ""
    @State private var filterStatus: InvoiceFilterStatus = .all
    
    enum InvoiceFilterStatus: String, CaseIterable {
        case all = "All"
        case unpaid = "Unpaid"
        case paid = "Paid"
        case overdue = "Overdue"
        
        var icon: String {
            switch self {
            case .all: return "doc.text"
            case .unpaid: return "clock"
            case .paid: return "checkmark.circle"
            case .overdue: return "exclamationmark.triangle"
            }
        }
    }
    
    // Get QuickBooks invoices for this customer
    var allInvoices: [Sale] {
        guard let salesSet = customer.sales as? Set<Sale> else { return [] }
        return salesSet
            .filter { $0.source == "quickbooks" }
            .sorted { ($0.saleDate ?? Date.distantPast) > ($1.saleDate ?? Date.distantPast) }
    }
    
    var filteredInvoices: [Sale] {
        var filtered = allInvoices
        
        // Filter by status
        switch filterStatus {
        case .all:
            break
        case .unpaid:
            filtered = filtered.filter { $0.paymentStatus == "unpaid" }
        case .paid:
            filtered = filtered.filter { $0.paymentStatus == "paid" }
        case .overdue:
            filtered = filtered.filter { $0.paymentStatus == "overdue" }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            filtered = filtered.filter { invoice in
                invoice.orderNumber?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Pills
            filterSection
            
            // Invoice List
            invoicesList
        }
        .navigationTitle("\(customer.displayName) Invoices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { /* TODO: Export */ }) {
                        Label("Export to CSV", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search invoices...")
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(InvoiceFilterStatus.allCases, id: \.self) { status in
                    InvoiceFilterPill(
                        title: status.rawValue,
                        icon: status.icon,
                        isSelected: filterStatus == status,
                        count: getCount(for: status)
                    )
                    .onTapGesture {
                        filterStatus = status
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    // MARK: - Invoices List
    
    private var invoicesList: some View {
        Group {
            if filteredInvoices.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredInvoices, id: \.id) { invoice in
                        NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                            InvoiceRow(invoice: invoice)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: filterStatus == .all ? "doc.text.magnifyingglass" : "doc.text.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text(emptyStateTitle)
                .font(.title2)
                .bold()
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if filterStatus != .all {
                Button(action: { filterStatus = .all }) {
                    Text("Clear Filter")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No Results"
        }
        switch filterStatus {
        case .all: return "No Invoices"
        case .unpaid: return "No Unpaid Invoices"
        case .paid: return "No Paid Invoices"
        case .overdue: return "No Overdue Invoices"
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No invoices match \"\(searchText)\""
        }
        switch filterStatus {
        case .all: return "Invoices will appear here after syncing from QuickBooks"
        case .unpaid: return "All invoices have been paid"
        case .paid: return "No payment history available"
        case .overdue: return "No overdue invoices"
        }
    }
    
    private func getCount(for status: InvoiceFilterStatus) -> Int {
        switch status {
        case .all: return allInvoices.count
        case .unpaid: return allInvoices.filter { $0.paymentStatus == "unpaid" }.count
        case .paid: return allInvoices.filter { $0.paymentStatus == "paid" }.count
        case .overdue: return allInvoices.filter { $0.paymentStatus == "overdue" }.count
        }
    }
}

// MARK: - Invoice Filter Pill Component (RENAMED to avoid conflict with ActiveFiltersBar.swift)

struct InvoiceFilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
            
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemBackground))
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(20)
    }
}

// MARK: - Invoice Row Component

struct InvoiceRow: View {
    let invoice: Sale
    
    private var isOverdue: Bool {
        invoice.paymentStatus != "paid" && (invoice.paymentDueDate ?? Date()) < Date()
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Invoice icon with status indicator
            ZStack(alignment: .topTrailing) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                
                if isOverdue {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .offset(x: 4, y: -4)
                }
            }
            
            // Invoice details
            VStack(alignment: .leading, spacing: 6) {
                Text(invoice.orderNumber ?? "Invoice")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if let date = invoice.saleDate {
                        Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if invoice.paymentStatus != "paid", let dueDate = invoice.paymentDueDate {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Label("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(isOverdue ? .red : .secondary)
                    }
                }
            }
            
            Spacer()
            
            // Amount and status
            VStack(alignment: .trailing, spacing: 6) {
                Text(invoice.formattedTotalAmount)
                    .font(.headline)
                
                Text(invoice.paymentStatusDisplayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(invoice.paymentStatusColor.opacity(0.2))
                    .foregroundColor(invoice.paymentStatusColor)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
    }
}
