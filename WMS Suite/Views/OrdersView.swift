//
//  OrdersView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
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
    @State private var selectedTimeframe = 0
    @State private var selectedSource: OrderSource? = nil  // nil = all sources
    @State private var showingAddOrder = false
    
    let timeframes = ["7 Days", "30 Days", "90 Days", "All Time"]
    
    var filteredSales: [Sale] {
        var filtered = Array(sales)
        
        // Filter by source
        if let source = selectedSource {
            filtered = filtered.filter { $0.orderSource == source }
        }
        
        // Filter by timeframe
        let calendar = Calendar.current
        let now = Date()
        switch selectedTimeframe {
        case 0: // 7 days
            filtered = filtered.filter { sale in
                guard let date = sale.saleDate else { return false }
                return calendar.dateComponents([.day], from: date, to: now).day ?? 999 <= 7
            }
        case 1: // 30 days
            filtered = filtered.filter { sale in
                guard let date = sale.saleDate else { return false }
                return calendar.dateComponents([.day], from: date, to: now).day ?? 999 <= 30
            }
        case 2: // 90 days
            filtered = filtered.filter { sale in
                guard let date = sale.saleDate else { return false }
                return calendar.dateComponents([.day], from: date, to: now).day ?? 999 <= 90
            }
        default: // All time
            break
        }
        
        // Filter by search text (search order number)
        if !searchText.isEmpty {
            filtered = filtered.filter { sale in
                sale.orderNumber?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        return filtered
    }
    
    var totalSales: Int32 {
        filteredSales.reduce(0) { $0 + $1.totalQuantity }
    }
    
    var averageDailySales: Double {
        guard !filteredSales.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let now = Date()
        var days = 1
        
        switch selectedTimeframe {
        case 0: days = 7
        case 1: days = 30
        case 2: days = 90
        default:
            if let oldestDate = filteredSales.last?.saleDate {
                days = max(1, calendar.dateComponents([.day], from: oldestDate, to: now).day ?? 1)
            }
        }
        
        return Double(totalSales) / Double(days)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Source Filter Tabs
                sourceFilterTabs
                
                // Summary Cards
                HStack(spacing: 12) {
                    SummaryCard(title: "Total Sales", value: "\(totalSales)", color: .blue)
                    SummaryCard(title: "Avg/Day", value: String(format: "%.1f", averageDailySales), color: .green)
                    SummaryCard(title: "Orders", value: "\(filteredSales.count)", color: .purple)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Timeframe Picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(0..<timeframes.count, id: \.self) { index in
                        Text(timeframes[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Orders List
                if filteredSales.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredSales, id: \.id) { sale in
                            NavigationLink(destination: OrderDetailView(sale: sale)) {
                                OrderRow(sale: sale)
                            }
                        }
                        .onDelete(perform: deleteOrders)
                    }
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
                // All orders tab
                SourceTabButton(
                    title: "All",
                    icon: "square.grid.2x2",
                    color: .gray,
                    isSelected: selectedSource == nil,
                    action: { selectedSource = nil }
                )
                
                // Local orders tab
                SourceTabButton(
                    title: OrderSource.local.displayName,
                    icon: OrderSource.local.icon,
                    color: OrderSource.local.color,
                    isSelected: selectedSource == .local,
                    action: { selectedSource = .local }
                )
                
                // Shopify orders tab
                SourceTabButton(
                    title: OrderSource.shopify.displayName,
                    icon: OrderSource.shopify.icon,
                    color: OrderSource.shopify.color,
                    isSelected: selectedSource == .shopify,
                    action: { selectedSource = .shopify }
                )
                
                // QuickBooks tab (greyed out for future)
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
    
    // MARK: - Actions
    
    private func deleteOrders(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredSales[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting orders: \(error)")
            }
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
