//
//  OrdersChartsView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI
import Charts
import CoreData

struct OrdersChartsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)],
        animation: .default)
    private var orders: FetchedResults<Sale>
    
    @State private var selectedPeriod: ChartPeriod = .thirtyDays
    @State private var dailyOrdersData: [DailyOrdersData] = []
    @State private var fulfillmentData: [FulfillmentStatusData] = []
    @State private var sourceData: [OrderSourceData] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                periodSelectorSection
                
                // Orders Over Time Chart
                ordersTrendChart
                
                // Fulfillment Status Chart
                fulfillmentStatusChart
                
                // Order Source Distribution
                orderSourceChart
                
                // Priority Orders Alert
                priorityOrdersSection
            }
            .padding()
        }
        .navigationTitle("Order Analytics")
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
    
    // MARK: - Orders Trend Chart
    
    private var ordersTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Orders Trend")
                .font(.headline)
            
            if dailyOrdersData.isEmpty {
                emptyChartView(message: "No orders data available")
            } else {
                Chart(dailyOrdersData) { data in
                    BarMark(
                        x: .value("Date", data.date),
                        y: .value("Orders", data.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                
                // Summary stats
                HStack(spacing: 20) {
                    StatCard(
                        title: "Total Orders",
                        value: "\(dailyOrdersData.reduce(0) { $0 + $1.count })",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Avg/Day",
                        value: String(format: "%.1f", averageDailyOrders()),
                        color: .green
                    )
                    
                    StatCard(
                        title: "Peak Day",
                        value: "\(peakDailyOrders())",
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
    
    // MARK: - Fulfillment Status Chart
    
    private var fulfillmentStatusChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fulfillment Status")
                .font(.headline)
            
            if fulfillmentData.isEmpty {
                emptyChartView(message: "No fulfillment data")
            } else {
                Chart(fulfillmentData) { data in
                    SectorMark(
                        angle: .value("Count", data.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Status", data.status))
                    .annotation(position: .overlay) {
                        VStack {
                            Text("\(data.count)")
                                .font(.headline)
                                .bold()
                            Text(data.status)
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                }
                .frame(height: 250)
                .chartLegend(position: .bottom)
                .chartForegroundStyleScale([
                    "Needs Fulfillment": Color.blue,
                    "In Transit": Color.orange,
                    "Delivered": Color.green,
                    "Unconfirmed": Color.yellow
                ])
                
                // Fulfillment metrics
                HStack(spacing: 12) {
                    ForEach(fulfillmentData) { data in
                        VStack(spacing: 4) {
                            Text("\(data.count)")
                                .font(.title3)
                                .bold()
                                .foregroundColor(statusColor(for: data.status))
                            Text(data.status)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(statusColor(for: data.status).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Order Source Chart
    
    private var orderSourceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Sources")
                .font(.headline)
            
            if sourceData.isEmpty {
                emptyChartView(message: "No order source data")
            } else {
                Chart(sourceData) { data in
                    BarMark(
                        x: .value("Source", data.source),
                        y: .value("Count", data.count)
                    )
                    .foregroundStyle(by: .value("Source", data.source))
                    .annotation(position: .top) {
                        Text("\(data.count)")
                            .font(.caption)
                            .bold()
                    }
                }
                .frame(height: 200)
                .chartForegroundStyleScale([
                    "Local": Color.blue,
                    "Shopify": Color.green,
                    "QuickBooks": Color.orange,
                    "Unknown": Color.gray
                ])
                
                // Source breakdown
                VStack(spacing: 8) {
                    ForEach(sourceData) { data in
                        HStack {
                            Circle()
                                .fill(sourceColorMap[data.source] ?? .gray)
                                .frame(width: 12, height: 12)
                            Text(data.source)
                                .font(.subheadline)
                            Spacer()
                            Text("\(data.count) orders")
                                .font(.subheadline)
                                .bold()
                            Text("(\(percentage(data.count))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Priority Orders Section
    
    private var priorityOrdersSection: some View {
        let priorityCount = orders.filter { $0.isPriority || $0.needsAttention }.count
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Priority Alerts")
                .font(.headline)
            
            if priorityCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(priorityCount) Priority Orders")
                            .font(.headline)
                        Text("Require immediate attention")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No priority orders")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
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
            dailyOrdersData = try loadDailyOrdersData()
            fulfillmentData = try loadFulfillmentData()
            sourceData = try loadSourceData()
        } catch {
            print("Error loading chart data: \(error)")
            // Graceful fallback
            dailyOrdersData = []
            fulfillmentData = []
            sourceData = []
        }
    }
    
    private func loadDailyOrdersData() throws -> [DailyOrdersData] {
        let days = selectedPeriod.days
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }
        
        let filteredOrders = orders.filter {
            guard let date = $0.saleDate else { return false }
            return date >= startDate && date <= endDate
        }
        
        // Group by date
        var dateMap: [Date: Int] = [:]
        for order in filteredOrders {
            guard let date = order.saleDate else { continue }
            let day = calendar.startOfDay(for: date)
            dateMap[day, default: 0] += 1
        }
        
        // Fill in missing dates
        var result: [DailyOrdersData] = []
        var currentDate = calendar.startOfDay(for: startDate)
        while currentDate <= endDate {
            result.append(DailyOrdersData(
                date: currentDate,
                count: dateMap[currentDate] ?? 0
            ))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return result
    }
    
    private func loadFulfillmentData() throws -> [FulfillmentStatusData] {
        var result: [FulfillmentStatusData] = []
        
        let needsFulfillment = orders.filter { $0.needsFulfillment }.count
        let inTransit = orders.filter { $0.isInTransit && !$0.isUnconfirmed }.count
        let delivered = orders.filter { $0.isDelivered }.count
        let unconfirmed = orders.filter { $0.isUnconfirmed }.count
        
        if needsFulfillment > 0 {
            result.append(FulfillmentStatusData(status: "Needs Fulfillment", count: needsFulfillment))
        }
        if inTransit > 0 {
            result.append(FulfillmentStatusData(status: "In Transit", count: inTransit))
        }
        if delivered > 0 {
            result.append(FulfillmentStatusData(status: "Delivered", count: delivered))
        }
        if unconfirmed > 0 {
            result.append(FulfillmentStatusData(status: "Unconfirmed", count: unconfirmed))
        }
        
        return result
    }
    
    private func loadSourceData() throws -> [OrderSourceData] {
        var sourceMap: [String: Int] = [:]
        
        for order in orders {
            let sourceName = order.orderSource?.displayName ?? "Unknown"
            sourceMap[sourceName, default: 0] += 1
        }
        
        return sourceMap
            .map { OrderSourceData(source: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    // MARK: - Calculations
    
    private func averageDailyOrders() -> Double {
        guard !dailyOrdersData.isEmpty else { return 0 }
        let total = dailyOrdersData.reduce(0) { $0 + $1.count }
        return Double(total) / Double(dailyOrdersData.count)
    }
    
    private func peakDailyOrders() -> Int {
        dailyOrdersData.map { $0.count }.max() ?? 0
    }
    
    private func percentage(_ count: Int) -> Int {
        let total = sourceData.reduce(0) { $0 + $1.count }
        guard total > 0 else { return 0 }
        return Int(Double(count) / Double(total) * 100)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Needs Fulfillment": return .blue
        case "In Transit": return .orange
        case "Delivered": return .green
        case "Unconfirmed": return .yellow
        default: return .gray
        }
    }
    
    private var sourceColorMap: [String: Color] {
        ["Local": .blue, "Shopify": .green, "QuickBooks": .orange, "Unknown": .gray]
    }
}

// MARK: - Data Models

struct DailyOrdersData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct FulfillmentStatusData: Identifiable {
    let id = UUID()
    let status: String
    let count: Int
}

struct OrderSourceData: Identifiable {
    let id = UUID()
    let source: String
    let count: Int
}
