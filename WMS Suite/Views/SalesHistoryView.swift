//
//  SalesHistoryView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI
import CoreData

struct SalesHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)],
        animation: .default)
    private var sales: FetchedResults<Sale>
    
    @State private var searchText = ""
    @State private var selectedTimeframe = 0
    let timeframes = ["7 Days", "30 Days", "90 Days", "All Time"]
    
    var filteredSales: [Sale] {
        var filtered = Array(sales)
        
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
            VStack {
                // Summary Cards
                HStack(spacing: 12) {
                    SummaryCard(title: "Total Sales", value: "\(totalSales)", color: .blue)
                    SummaryCard(title: "Avg/Day", value: String(format: "%.1f", averageDailySales), color: .green)
                    SummaryCard(title: "Orders", value: "\(filteredSales.count)", color: .purple)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Timeframe Picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(0..<timeframes.count, id: \.self) { index in
                        Text(timeframes[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Sales List
                if filteredSales.isEmpty {
                    ContentUnavailableView(
                        "No Sales Data",
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text("Add sales manually or sync from Shopify to see sales history")
                    )
                } else {
                    List {
                        ForEach(filteredSales) { sale in
                            SaleRowView(sale: sale)
                        }
                        .onDelete(perform: deleteSales)
                    }
                }
            }
            .navigationTitle("Sales History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteSales(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredSales[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting sales: \(error)")
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SaleRowView: View {
    let sale: Sale
    @Environment(\.managedObjectContext) private var viewContext
    
    var lineItemsArray: [SaleLineItem] {
        guard let items = sale.lineItems as? Set<SaleLineItem> else { return [] }
        return Array(items).sorted { ($0.item?.name ?? "") < ($1.item?.name ?? "") }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let orderNumber = sale.orderNumber, !orderNumber.isEmpty {
                        Text("Order: \(orderNumber)")
                            .font(.headline)
                    } else {
                        Text("Sale #\(sale.id)")
                            .font(.headline)
                    }
                    
                    if let date = sale.saleDate {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(sale.totalQuantity) units")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("\(lineItemsArray.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Line Items
            if !lineItemsArray.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lineItemsArray, id: \.id) { lineItem in
                        HStack {
                            Text(lineItem.item?.name ?? "Unknown Item")
                                .font(.subheadline)
                            Spacer()
                            Text("×\(lineItem.quantity)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SalesHistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
