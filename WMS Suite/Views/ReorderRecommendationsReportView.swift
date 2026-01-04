//
//  ReorderRecommendationsReportView.swift
//  WMS Suite
//
//  Smart reorder recommendations based on stock levels and sales velocity
//

import SwiftUI

struct ReorderRecommendationsReportView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var recommendations: [ReorderRecommendation] = []
    @State private var isLoading = true
    @State private var leadTimeDays: Int = 7
    @State private var filterPriority: ReorderPriority?
    @State private var showingSettings = false
    @State private var usingSalesData = false // Track if we have sales data
    
    var filteredRecommendations: [ReorderRecommendation] {
        if let filterPriority = filterPriority {
            return recommendations.filter { $0.priority == filterPriority }
        }
        return recommendations
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if recommendations.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle("Reorder Recommendations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                    
                    Button(action: analyzeInventory) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            analyzeInventory()
        }
        .sheet(isPresented: $showingSettings) {
            ReorderSettingsView(leadTimeDays: $leadTimeDays) {
                analyzeInventory()
            }
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Analyzing inventory and sales data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("All Good!")
                .font(.title2)
                .bold()
            
            Text("No reorder recommendations at this time. All items have sufficient stock levels.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var contentView: some View {
        List {
            // Info banner if no sales data
            if !usingSalesData {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Limited Data")
                                .font(.subheadline)
                                .bold()
                            Text("Recommendations based on stock levels only. Connect Shopify or add sales to enable velocity-based recommendations.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Summary Section
            Section {
                summaryCard
            }
            
            // Filter Section
            Section {
                filterPicker
            }
            
            // Recommendations List
            Section {
                ForEach(filteredRecommendations) { recommendation in
                    NavigationLink(destination: ReorderDetailView(recommendation: recommendation, viewModel: viewModel)) {
                        ReorderRow(recommendation: recommendation)
                    }
                }
            } header: {
                Text("\(filteredRecommendations.count) Recommendation\(filteredRecommendations.count == 1 ? "" : "s")")
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items to Reorder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recommendations.count)")
                        .font(.title)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Lead Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(leadTimeDays) days")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            // Priority breakdown
            VStack(spacing: 8) {
                ForEach([ReorderPriority.critical, .high, .medium, .low], id: \.self) { priority in
                    let count = recommendations.filter { $0.priority == priority }.count
                    if count > 0 {
                        HStack {
                            Circle()
                                .fill(priority.color)
                                .frame(width: 12, height: 12)
                            Text(priority.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text("\(count)")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(priority.color)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                PriorityFilterChip(
                    title: "All",
                    count: recommendations.count,
                    isSelected: filterPriority == nil,
                    color: .blue
                ) {
                    filterPriority = nil
                }
                
                ForEach([ReorderPriority.critical, .high, .medium, .low], id: \.self) { priority in
                    let count = recommendations.filter { $0.priority == priority }.count
                    if count > 0 {
                        PriorityFilterChip(
                            title: priority.displayName,
                            count: count,
                            isSelected: filterPriority == priority,
                            color: priority.color
                        ) {
                            filterPriority = priority
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Actions
    
    private func analyzeInventory() {
        isLoading = true
        
        Task {
            // Fetch sales history for all items
            var salesHistoryMap: [String: [SalesHistoryDisplay]] = [:]
            var hasSalesData = false
            
            for item in viewModel.items {
                if let sku = item.sku {
                    do {
                        let history = try await viewModel.shopifyService.fetchRecentSales(for: item)
                        salesHistoryMap[sku] = history
                        if !history.isEmpty {
                            hasSalesData = true
                        }
                    } catch {
                        print("⚠️ Failed to fetch sales history for \(sku): \(error)")
                    }
                }
            }
            
            await MainActor.run {
                usingSalesData = hasSalesData
                recommendations = ReorderRecommendationService.generateRecommendations(
                    for: viewModel.items,
                    salesHistory: salesHistoryMap,
                    leadTimeDays: leadTimeDays
                )
                isLoading = false
            }
        }
    }
}

// MARK: - Reorder Row Component

struct ReorderRow: View {
    let recommendation: ReorderRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recommendation.item.name ?? "Unknown Item")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(recommendation.priority.color)
                    .frame(width: 12, height: 12)
            }
            
            HStack {
                Image(systemName: recommendation.reason.icon)
                    .foregroundColor(recommendation.reason.color)
                    .frame(width: 20)
                
                Text(recommendation.reason.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Stock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recommendation.currentStock)")
                        .font(.subheadline)
                        .bold()
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended Order")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recommendation.recommendedOrderQuantity)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if recommendation.daysOfStockRemaining <= 7 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(recommendation.daysOfStockRemaining)")
                            .font(.title3)
                            .bold()
                            .foregroundColor(recommendation.priority.color)
                        Text("days left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Priority Filter Chip

struct PriorityFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(uiColor: .secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Reorder Settings View

struct ReorderSettingsView: View {
    @Binding var leadTimeDays: Int
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper("Lead Time: \(leadTimeDays) days", value: $leadTimeDays, in: 1...30)
                } header: {
                    Text("Reorder Settings")
                } footer: {
                    Text("Lead time is the number of days it typically takes to receive a reorder. This affects when recommendations are triggered.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Reorder Detail View

struct ReorderDetailView: View {
    let recommendation: ReorderRecommendation
    @ObservedObject var viewModel: InventoryViewModel
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation.item.name ?? "Unknown Item")
                                .font(.title2)
                                .bold()
                            
                            if let sku = recommendation.item.sku {
                                Text("SKU: \(sku)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(recommendation.priority.displayName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(recommendation.priority.color.opacity(0.2))
                                .foregroundColor(recommendation.priority.color)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            Section {
                HStack {
                    Image(systemName: recommendation.reason.icon)
                        .foregroundColor(recommendation.reason.color)
                    Text("Reason")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(recommendation.reason.rawValue)
                        .font(.subheadline)
                }
            }
            
            Section {
                DetailRow(label: "Current Stock", value: "\(recommendation.currentStock)")
                DetailRow(label: "Recommended Order Quantity", value: "\(recommendation.recommendedOrderQuantity)", valueColor: .blue)
                DetailRow(label: "Days of Stock Remaining", value: "\(recommendation.daysOfStockRemaining)")
                
                if recommendation.averageDailySales > 0 {
                    DetailRow(label: "Average Daily Sales", value: String(format: "%.1f", recommendation.averageDailySales))
                }
                
                if let stockoutDate = recommendation.estimatedStockoutDate {
                    DetailRow(
                        label: "Estimated Stockout Date",
                        value: stockoutDate.formatted(date: .abbreviated, time: .omitted),
                        valueColor: .red
                    )
                }
            } header: {
                Text("Stock Analysis")
            }
            
            Section {
                NavigationLink(destination: ProductDetailView(viewModel: viewModel, item: recommendation.item)) {
                    Text("View Product Details")
                }
            }
        }
        .navigationTitle("Reorder Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}
