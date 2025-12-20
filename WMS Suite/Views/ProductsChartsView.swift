//
//  ProductsChartsView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI
import Charts
import CoreData

struct ProductsChartsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \InventoryItem.name, ascending: true)],
        animation: .default)
    private var items: FetchedResults<InventoryItem>
    
    @State private var selectedPeriod: ChartPeriod = .thirtyDays
    @State private var salesData: [DailySalesData] = []
    @State private var lowStockItems: [InventoryItem] = []
    @State private var topSellingItems: [ProductSalesData] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                periodSelectorSection
                
                // Sales Over Time Chart
                salesTrendChart
                
                // Low Stock Alert Chart
                lowStockChart
                
                // Top Selling Products Chart
                topSellingChart
                
                // Inventory Value Distribution
                inventoryValueChart
            }
            .padding()
        }
        .navigationTitle("Product Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChartData()
        }
        .onChange(of: selectedPeriod) { _ in
            loadChartData()
        }
    }
    
    // MARK: - Period Selector
    
    private var periodSelectorSection: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            ForEach(ChartPeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Sales Trend Chart
    
    private var salesTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sales Trend")
                .font(.headline)
            
            if salesData.isEmpty {
                emptyChartView(message: "No sales data available")
            } else {
                Chart(salesData) { data in
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Units", data.units)
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", data.date),
                        y: .value("Units", data.units)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                
                // Summary stats
                HStack(spacing: 20) {
                    StatCard(
                        title: "Total Units",
                        value: "\(salesData.reduce(0) { $0 + $1.units })",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Avg/Day",
                        value: String(format: "%.1f", averageDailySales()),
                        color: .green
                    )
                    
                    StatCard(
                        title: "Peak Day",
                        value: "\(peakDailySales())",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Low Stock Chart
    
    private var lowStockChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Low Stock Alert")
                .font(.headline)
            
            if lowStockItems.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All products adequately stocked")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                Chart(lowStockItems.prefix(10), id: \.id) { item in
                    BarMark(
                        x: .value("Quantity", Int(item.quantity)),
                        y: .value("Product", item.name ?? "Unknown")
                    )
                    .foregroundStyle(stockColor(for: item))
                }
                .frame(height: CGFloat(min(lowStockItems.count, 10)) * 40)
                
                Text("\(lowStockItems.count) products below minimum stock level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Top Selling Chart
    
    private var topSellingChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Selling Products")
                .font(.headline)
            
            if topSellingItems.isEmpty {
                emptyChartView(message: "No sales data available")
            } else {
                Chart(topSellingItems) { data in
                    BarMark(
                        x: .value("Units", data.unitsSold),
                        y: .value("Product", data.productName)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .annotation(position: .trailing) {
                        Text("\(data.unitsSold)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: CGFloat(topSellingItems.count) * 40)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Inventory Value Chart
    
    private var inventoryValueChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory Distribution")
                .font(.headline)
            
            let distribution = inventoryDistribution()
            
            if distribution.isEmpty {
                emptyChartView(message: "No inventory data")
            } else {
                Chart(distribution) { data in
                    SectorMark(
                        angle: .value("Count", data.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Category", data.category))
                    .annotation(position: .overlay) {
                        VStack {
                            Text("\(data.count)")
                                .font(.headline)
                                .bold()
                            Text(data.category)
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                }
                .frame(height: 250)
                .chartLegend(position: .bottom)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Helper Views
    
    private func emptyChartView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }
    
    // MARK: - Data Loading
    
    private func loadChartData() {
        do {
            // Load sales trend data
            salesData = try loadSalesTrendData()
            
            // Load low stock items
            lowStockItems = Array(items.filter { $0.quantity < $0.minStockLevel && $0.minStockLevel > 0 })
            
            // Load top selling items
            topSellingItems = try loadTopSellingData()
        } catch {
            print("Error loading chart data: \(error)")
            // Graceful fallback - empty data will show empty state
            salesData = []
            lowStockItems = []
            topSellingItems = []
        }
    }
    
    private func loadSalesTrendData() throws -> [DailySalesData] {
        let days = selectedPeriod.days
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }
        
        // Fetch all sales in period
        let request = NSFetchRequest<Sale>(entityName: "Sale")
        request.predicate = NSPredicate(format: "saleDate >= %@ AND saleDate <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: true)]
        
        let sales = try viewContext.fetch(request)
        
        // Group by date
        var dateMap: [Date: Int32] = [:]
        for sale in sales {
            guard let date = sale.saleDate else { continue }
            let day = calendar.startOfDay(for: date)
            dateMap[day, default: 0] += sale.totalQuantity
        }
        
        // Fill in missing dates with 0
        var result: [DailySalesData] = []
        var currentDate = calendar.startOfDay(for: startDate)
        while currentDate <= endDate {
            result.append(DailySalesData(
                date: currentDate,
                units: Int(dateMap[currentDate] ?? 0)
            ))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return result
    }
    
    private func loadTopSellingData() throws -> [ProductSalesData] {
        let days = selectedPeriod.days
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }
        
        // Fetch all line items in period
        let request = NSFetchRequest<SaleLineItem>(entityName: "SaleLineItem")
        request.predicate = NSPredicate(format: "sale.saleDate >= %@", startDate as NSDate)
        
        let lineItems = try viewContext.fetch(request)
        
        // Group by product
        var productSales: [String: Int32] = [:]
        for lineItem in lineItems {
            guard let productName = lineItem.item?.name else { continue }
            productSales[productName, default: 0] += lineItem.quantity
        }
        
        // Convert to array and sort
        return productSales
            .map { ProductSalesData(productName: $0.key, unitsSold: Int($0.value)) }
            .sorted { $0.unitsSold > $1.unitsSold }
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Calculations
    
    private func averageDailySales() -> Double {
        guard !salesData.isEmpty else { return 0 }
        let total = salesData.reduce(0) { $0 + $1.units }
        return Double(total) / Double(salesData.count)
    }
    
    private func peakDailySales() -> Int {
        salesData.map { $0.units }.max() ?? 0
    }
    
    private func stockColor(for item: InventoryItem) -> Color {
        if item.quantity == 0 {
            return .red
        } else if item.quantity < item.minStockLevel / 2 {
            return .orange
        } else {
            return .yellow
        }
    }
    
    private func inventoryDistribution() -> [InventoryDistributionData] {
        let inStock = items.filter { $0.quantity > $0.minStockLevel }.count
        let lowStock = items.filter { $0.quantity <= $0.minStockLevel && $0.quantity > 0 }.count
        let outOfStock = items.filter { $0.quantity == 0 }.count
        
        var result: [InventoryDistributionData] = []
        if inStock > 0 {
            result.append(InventoryDistributionData(category: "In Stock", count: inStock))
        }
        if lowStock > 0 {
            result.append(InventoryDistributionData(category: "Low Stock", count: lowStock))
        }
        if outOfStock > 0 {
            result.append(InventoryDistributionData(category: "Out of Stock", count: outOfStock))
        }
        
        return result
    }
}

// MARK: - Data Models

struct DailySalesData: Identifiable {
    let id = UUID()
    let date: Date
    let units: Int
}

struct ProductSalesData: Identifiable {
    let id = UUID()
    let productName: String
    let unitsSold: Int
}

struct InventoryDistributionData: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
}

// MARK: - Chart Period Enum

enum ChartPeriod: String, CaseIterable, Identifiable {
    case sevenDays = "7d"
    case fourteenDays = "14d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .fourteenDays: return "14 Days"
        case .thirtyDays: return "30 Days"
        case .ninetyDays: return "90 Days"
        }
    }
    
    var days: Int {
        switch self {
        case .sevenDays: return 7
        case .fourteenDays: return 14
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
