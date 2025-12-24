//
//  InvoicesListView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/24/25.
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
    
    // TODO: Replace with actual fetch request after Invoice entity is created
    // @FetchRequest private var invoices: FetchedResults<Invoice>
    
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
                    Button(action: { /* TODO: Sync invoices */ }) {
                        Label("Sync from QuickBooks", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
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
            // TODO: Replace with actual invoice fetch
            if true { // Will be: filteredInvoices.isEmpty
                emptyStateView
            } else {
                List {
                    // TODO: Loop through filteredInvoices
                    ForEach(0..<5, id: \.self) { index in
                        Button(action: {
                            // TODO: Navigate to InvoiceDetailView
                        }) {
                            InvoiceRow(
                                invoiceNumber: "INV-\(1000 + index)",
                                date: Date(),
                                amount: Decimal(string: "\(100 * (index + 1))") ?? 0,
                                status: index % 3 == 0 ? "Paid" : "Unpaid",
                                dueDate: Date().addingTimeInterval(86400 * 30)
                            )
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
    
    // TODO: Wire up actual counts after Invoice entity
    private func getCount(for status: InvoiceFilterStatus) -> Int {
        return 0
    }
}

// MARK: - Filter Pill Component

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
    let invoiceNumber: String
    let date: Date
    let amount: Decimal
    let status: String
    let dueDate: Date
    
    private var isOverdue: Bool {
        status != "Paid" && dueDate < Date()
    }
    
    private var statusColor: Color {
        switch status {
        case "Paid": return .green
        case "Unpaid": return isOverdue ? .red : .orange
        default: return .gray
        }
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
                Text(invoiceNumber)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if status != "Paid" {
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
                Text(amount as NSDecimalNumber, formatter: currencyFormatter)
                    .font(.headline)
                
                Text(status)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }
}

// MARK: - Preview

struct InvoicesListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            InvoicesListView(customer: Customer())
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
