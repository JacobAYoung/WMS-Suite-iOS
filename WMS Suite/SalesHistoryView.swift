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
        sortDescriptors: [NSSortDescriptor(keyPath: \SalesHistory.saleDate, ascending: false)],
        animation: .default)
    private var sales: FetchedResults<SalesHistory>
    
    @State private var searchText = ""
    @State private var selectedTimeframe = 0
    let timeframes = ["7 Days", "30 Days", "90 Days", "All Time"]
    
    var filteredSales: [SalesHistory] {
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
        
        // Filter by search text
        if !searchText.isEmpty {
            // Since we don't have itemSKU yet, we can't search by it
            // For now, just return all
            return filtered
        }
        
        return filtered
    }
    
    var totalSales: Int {
        filteredSales.reduce(0) { $0 + Int($1.soldQuantity) }
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
                            SalesRow(sale: sale)
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

struct SalesRow: View {
    let sale: SalesHistory
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sale.soldQuantity) units sold")
                    .font(.headline)
                
                if let date = sale.saleDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "cart.fill")
                .foregroundColor(.blue)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}
