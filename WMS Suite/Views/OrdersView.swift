//
//  OrdersView.swift
//  WMS Suite
//
//  Enhanced: Added status sections, priority orders, fulfillment filtering
//

import SwiftUI
import CoreData

struct OrdersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)],
        animation: .default)
    private var sales: FetchedResults<Sale>
    
    @State private var searchText = ""
    @State private var selectedSource: OrderSource? = nil
    @State private var selectedStatus: OrderFulfillmentStatus? = nil
    @State private var showingAddOrder = false
    
    var filteredSales: [Sale] {
        var filtered = Array(sales)
        
        // Filter by source
        if let source = selectedSource {
            filtered = filtered.filter { $0.orderSource == source }
        }
        
        // Filter by status
        if let status = selectedStatus {
            filtered = filtered.filter { sale in
                // Handle special cases
                if status == .unconfirmed {
                    return sale.isUnconfirmed
                } else {
                    return sale.fulfillmentStatusEnum == status
                }
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { sale in
                sale.orderNumber?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        return filtered
    }
    
    // Priority orders (always at top)
    var priorityOrders: [Sale] {
        filteredSales.filter { $0.isPriority || $0.needsAttention }
    }
    
    // Orders by status
    var needsFulfillmentOrders: [Sale] {
        filteredSales.filter { $0.needsFulfillment && !$0.hasFlagsSet }
    }
    
    var inTransitOrders: [Sale] {
        filteredSales.filter { $0.isInTransit && !$0.isUnconfirmed && !$0.hasFlagsSet }
    }
    
    var unconfirmedOrders: [Sale] {
        filteredSales.filter { $0.isUnconfirmed && !$0.hasFlagsSet }
    }
    
    var deliveredOrders: [Sale] {
        filteredSales.filter { $0.isDelivered && !$0.hasFlagsSet }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Source Filter Tabs
                sourceFilterTabs
                
                // Status Filter Tabs
                statusFilterTabs
                
                // Orders List with Sections
                if filteredSales.isEmpty {
                    emptyStateView
                } else {
                    ordersList
                }
            }
            .navigationTitle("Orders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddOrder = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search order number...")
            .sheet(isPresented: $showingAddOrder) {
                AddSalesView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    // MARK: - Source Filter Tabs
    
    private var sourceFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SourceTabButton(
                    title: "All",
                    icon: "square.grid.2x2",
                    color: .gray,
                    isSelected: selectedSource == nil,
                    action: { selectedSource = nil }
                )
                
                SourceTabButton(
                    title: OrderSource.local.displayName,
                    icon: OrderSource.local.icon,
                    color: OrderSource.local.color,
                    isSelected: selectedSource == .local,
                    action: { selectedSource = .local }
                )
                
                SourceTabButton(
                    title: OrderSource.shopify.displayName,
                    icon: OrderSource.shopify.icon,
                    color: OrderSource.shopify.color,
                    isSelected: selectedSource == .shopify,
                    action: { selectedSource = .shopify }
                )
                
                SourceTabButton(
                    title: OrderSource.quickbooks.displayName,
                    icon: OrderSource.quickbooks.icon,
                    color: .gray,
                    isSelected: false,
                    action: { },
                    isDisabled: true
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    // MARK: - Status Filter Tabs
    
    private var statusFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatusTabButton(
                    title: "All",
                    icon: "square.grid.2x2",
                    color: .gray,
                    count: nil,
                    isSelected: selectedStatus == nil,
                    action: { selectedStatus = nil }
                )
                
                ForEach(OrderFulfillmentStatus.allCases) { status in
                    StatusTabButton(
                        title: status.displayName,
                        icon: status.icon,
                        color: status.color,
                        count: countForStatus(status),
                        isSelected: selectedStatus == status,
                        action: { selectedStatus = status }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .tertiarySystemBackground))
    }
    
    // MARK: - Orders List
    
    private var ordersList: some View {
        List {
            // Priority Section (always first if not empty)
            if !priorityOrders.isEmpty && selectedStatus == nil {
                Section {
                    ForEach(priorityOrders, id: \.id) { sale in
                        NavigationLink(destination: OrderDetailView(sale: sale)) {
                            OrderRow(sale: sale)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Priority Orders")
                    }
                    .foregroundColor(.red)
                }
            }
            
            // Status-specific sections (if no status filter selected)
            if selectedStatus == nil {
                if !needsFulfillmentOrders.isEmpty {
                    Section {
                        ForEach(needsFulfillmentOrders, id: \.id) { sale in
                            NavigationLink(destination: OrderDetailView(sale: sale)) {
                                OrderRow(sale: sale)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: OrderFulfillmentStatus.needsFulfillment.icon)
                            Text("Needs Fulfillment (\(needsFulfillmentOrders.count))")
                        }
                    }
                }
                
                if !inTransitOrders.isEmpty {
                    Section {
                        ForEach(inTransitOrders, id: \.id) { sale in
                            NavigationLink(destination: OrderDetailView(sale: sale)) {
                                OrderRow(sale: sale)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: OrderFulfillmentStatus.inTransit.icon)
                            Text("In Transit (\(inTransitOrders.count))")
                        }
                    }
                }
                
                if !unconfirmedOrders.isEmpty {
                    Section {
                        ForEach(unconfirmedOrders, id: \.id) { sale in
                            NavigationLink(destination: OrderDetailView(sale: sale)) {
                                OrderRow(sale: sale)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: OrderFulfillmentStatus.unconfirmed.icon)
                            Text("Unconfirmed (\(unconfirmedOrders.count))")
                        }
                        .foregroundColor(.yellow)
                    }
                }
                
                if !deliveredOrders.isEmpty {
                    Section {
                        ForEach(deliveredOrders, id: \.id) { sale in
                            NavigationLink(destination: OrderDetailView(sale: sale)) {
                                OrderRow(sale: sale)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: OrderFulfillmentStatus.delivered.icon)
                            Text("Delivered (\(deliveredOrders.count))")
                        }
                    }
                }
            } else {
                // When status filter is selected, show all matching orders
                Section {
                    ForEach(filteredSales, id: \.id) { sale in
                        NavigationLink(destination: OrderDetailView(sale: sale)) {
                            OrderRow(sale: sale)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Orders")
                .font(.title2)
                .bold()
            
            if selectedSource != nil {
                Text("No orders from \(selectedSource!.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if selectedStatus != nil {
                Text("No orders with status: \(selectedStatus!.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if !searchText.isEmpty {
                Text("No orders match \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Add your first order to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showingAddOrder = true }) {
                Label("Add Order", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helpers
    
    private func countForStatus(_ status: OrderFulfillmentStatus) -> Int {
        switch status {
        case .needsFulfillment:
            return sales.filter { $0.needsFulfillment }.count
        case .inTransit:
            return sales.filter { $0.isInTransit && !$0.isUnconfirmed }.count
        case .unconfirmed:
            return sales.filter { $0.isUnconfirmed }.count
        case .delivered:
            return sales.filter { $0.isDelivered }.count
        }
    }
}

// MARK: - Status Tab Button

struct StatusTabButton: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? color : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Source Tab Button

struct SourceTabButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color.clear)
            .foregroundColor(isDisabled ? .gray : (isSelected ? color : .primary))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}
