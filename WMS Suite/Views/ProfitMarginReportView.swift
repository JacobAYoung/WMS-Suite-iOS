//
//  ProfitMarginReportView.swift
//  WMS Suite
//
//  Profit margin calculator and analyzer
//

import SwiftUI

struct ProfitMarginReportView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var analyses: [ProductMarginAnalysis] = []
    @State private var summary: MarginSummary?
    @State private var searchText = ""
    @State private var selectedCategory: MarginCategory?
    @State private var showingCalculator = false
    @State private var showingProductDetail: InventoryItem?
    
    var filteredAnalyses: [ProductMarginAnalysis] {
        var results = analyses
        
        // Filter by category
        if let category = selectedCategory {
            results = results.filter { $0.marginCategory == category }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            results = results.filter { analysis in
                let name = analysis.item.name?.lowercased() ?? ""
                let sku = analysis.item.sku?.lowercased() ?? ""
                let search = searchText.lowercased()
                return name.contains(search) || sku.contains(search)
            }
        }
        
        return results
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick Calculator Button
                quickCalculatorButton
                
                // Summary Cards
                if let summary = summary {
                    summarySection(summary)
                }
                
                // Category Breakdown Chart
                if !analyses.isEmpty {
                    categoryChartSection
                }
                
                // Search & Filter
                searchAndFilterSection
                
                // Product List
                if !filteredAnalyses.isEmpty {
                    productListSection
                } else if searchText.isEmpty && selectedCategory == nil {
                    noDataView
                } else {
                    noResultsView
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Profit Margins")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: analyzeMargins) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            analyzeMargins()
        }
        .sheet(isPresented: $showingCalculator) {
            ProfitMarginCalculatorView()
        }
        .sheet(item: $showingProductDetail) { item in
            NavigationView {
                ProductDetailView(viewModel: viewModel, item: item)
            }
        }
    }
    
    // MARK: - View Components
    
    private var quickCalculatorButton: some View {
        Button(action: { showingCalculator = true }) {
            HStack {
                Image(systemName: "function")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.green)
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Margin Calculator")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Calculate margins for any cost & price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    private func summarySection(_ summary: MarginSummary) -> some View {
        VStack(spacing: 16) {
            Text("Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Top metrics
            HStack(spacing: 12) {
                MetricCard(
                    title: "Avg Margin",
                    value: String(format: "%.1f%%", NSDecimalNumber(decimal: summary.averageMargin).doubleValue),
                    color: summary.averageMargin < 20 ? .orange : .green,
                    icon: "percent"
                )
                
                MetricCard(
                    title: "Total Profit",
                    value: formatCurrency(summary.totalPotentialProfit),
                    color: .blue,
                    icon: "dollarsign.circle.fill"
                )
            }
            
            // Problem areas
            HStack(spacing: 12) {
                MetricCard(
                    title: "Negative Margin",
                    value: "\(summary.negativeMarginCount)",
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
                
                MetricCard(
                    title: "Low Margin",
                    value: "\(summary.lowMarginCount)",
                    color: .orange,
                    icon: "arrow.down.circle.fill"
                )
            }
            
            // Coverage
            VStack(spacing: 8) {
                HStack {
                    Text("Products with Pricing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(summary.productsWithPricing) of \(summary.totalProducts)")
                        .font(.subheadline)
                        .bold()
                }
                
                ProgressView(value: summary.pricingCoverage, total: 100)
                    .tint(summary.pricingCoverage > 80 ? .green : .orange)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private var categoryChartSection: some View {
        VStack(spacing: 16) {
            Text("Margin Distribution")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            let breakdown = ProfitMarginService.getCategoryBreakdown(analyses)
            
            // Bar chart
            VStack(alignment: .leading, spacing: 12) {
                ForEach(MarginCategory.allCases, id: \.self) { category in
                    let count = breakdown[category] ?? 0
                    if count > 0 {
                        CategoryBar(
                            category: category,
                            count: count,
                            total: analyses.count,
                            isSelected: selectedCategory == category
                        ) {
                            if selectedCategory == category {
                                selectedCategory = nil
                            } else {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by name or SKU", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            
            // Active filter
            if selectedCategory != nil {
                HStack {
                    Text("Filtered by: \(selectedCategory?.rawValue ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear") {
                        selectedCategory = nil
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var productListSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(filteredAnalyses.count) Product\(filteredAnalyses.count == 1 ? "" : "s")")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(filteredAnalyses) { analysis in
                    ProductMarginRow(analysis: analysis) {
                        showingProductDetail = analysis.item
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Pricing Data")
                .font(.title2)
                .bold()
            
            Text("Add costs and selling prices to your products to see margin analysis")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Results")
                .font(.title2)
                .bold()
            
            Text("No products match your search or filter criteria")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func analyzeMargins() {
        analyses = ProfitMarginService.analyzeProducts(viewModel.items)
        summary = ProfitMarginService.generateSummary(from: viewModel.items, analyses: analyses)
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Category Bar Component

struct CategoryBar: View {
    let category: MarginCategory
    let count: Int
    let total: Int
    let isSelected: Bool
    let action: () -> Void
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                        .frame(width: 20)
                    
                    Text(category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("(\(category.range))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(category.color)
                    
                    Text(String(format: "%.0f%%", percentage * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(category.color)
                            .frame(width: geometry.size.width * percentage, height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(isSelected ? category.color.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Product Margin Row Component

struct ProductMarginRow: View {
    let analysis: ProductMarginAnalysis
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Category indicator
                Circle()
                    .fill(analysis.marginCategory.color)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.item.name ?? "Unknown Item")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let sku = analysis.item.sku {
                        Text("SKU: \(sku)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Cost: \(formatCurrency(analysis.cost))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("Price: \(formatCurrency(analysis.sellingPrice))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", analysis.marginPercentage))
                        .font(.title3)
                        .bold()
                        .foregroundColor(analysis.marginCategory.color)
                    
                    Text(analysis.marginCategory.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}
