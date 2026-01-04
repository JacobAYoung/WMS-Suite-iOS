//
//  InventoryValueReportView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/29/24.
//

import SwiftUI

struct InventoryValueReportView: View {
    @ObservedObject var viewModel: InventoryViewModel
    
    private var totalItems: Int {
        viewModel.items.count
    }
    
    private var totalQuantity: Int {
        viewModel.items.reduce(0) { $0 + Int($1.quantity) }
    }
    
    // Shopify-specific metrics
    private var shopifyItems: [InventoryItem] {
        viewModel.items.filter { $0.shopifyPrice != nil }
    }
    
    private var shopifyCostValue: Decimal {
        shopifyItems.reduce(0) { total, item in
            total + (item.cost * Decimal(item.quantity))
        }
    }
    
    private var shopifySellingValue: Decimal {
        shopifyItems.reduce(0) { total, item in
            guard let price = item.shopifyPrice else { return total }
            return total + (price * Decimal(item.quantity))
        }
    }
    
    // QuickBooks-specific metrics
    private var quickbooksItems: [InventoryItem] {
        viewModel.items.filter { $0.quickbooksPrice != nil }
    }
    
    private var quickbooksCostValue: Decimal {
        quickbooksItems.reduce(0) { total, item in
            total + (item.quickbooksCost * Decimal(item.quantity))
        }
    }
    
    private var quickbooksSellingValue: Decimal {
        quickbooksItems.reduce(0) { total, item in
            guard let price = item.quickbooksPrice else { return total }
            return total + (price * Decimal(item.quantity))
        }
    }
    
    // Manual/Local-specific metrics
    // Items with manual pricing are those that have a selling price set but no Shopify or QuickBooks price
    private var manualItems: [InventoryItem] {
        viewModel.items.filter { item in
            // Has manual pricing if:
            // 1. Has a selling price (from manual entry)
            // 2. Does NOT have Shopify or QuickBooks pricing
            let hasSellingPrice = item.sellingPrice != nil && item.sellingPrice! > 0
            let hasShopifyPrice = item.shopifyPrice != nil && item.shopifyPrice! > 0
            let hasQuickBooksPrice = item.quickbooksPrice != nil && item.quickbooksPrice! > 0
            
            let isManual = hasSellingPrice && !hasShopifyPrice && !hasQuickBooksPrice
            
            return isManual
        }
    }
    
    private var manualCostValue: Decimal {
        manualItems.reduce(Decimal(0)) { total, item in
            let cost = item.cost
            let qty = Int(item.quantity)
            return total + (cost * Decimal(qty))
        }
    }
    
    private var manualSellingValue: Decimal {
        manualItems.reduce(Decimal(0)) { total, item in
            guard let sellingPrice = item.sellingPrice else {
                return total
            }
            
            let qty = Int(item.quantity)
            return total + (sellingPrice * Decimal(qty))
        }
    }
    
    // Total metrics (using smart properties)
    private var totalCostValue: Decimal {
        viewModel.items.reduce(0) { total, item in
            total + (item.cost * Decimal(item.quantity))
        }
    }
    
    private var totalSellingValue: Decimal {
        viewModel.items.reduce(0) { total, item in
            guard let price = item.sellingPrice else { return total }
            return total + (price * Decimal(item.quantity))
        }
    }
    
    private var itemsWithPricing: Int {
        viewModel.items.filter { $0.sellingPrice != nil && $0.cost > 0 }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Summary
                VStack(spacing: 16) {
                    ReportSummaryCard(
                        title: "Total Items",
                        value: "\(totalItems)",
                        subtitle: "\(totalQuantity) units in stock",
                        icon: "shippingbox.fill",
                        color: .blue
                    )
                    
                    ReportSummaryCard(
                        title: "Total Cost Value",
                        value: formatCurrency(totalCostValue),
                        subtitle: "All inventory cost",
                        icon: "dollarsign.circle.fill",
                        color: .orange
                    )
                    
                    if totalSellingValue > 0 {
                        ReportSummaryCard(
                            title: "Total Retail Value",
                            value: formatCurrency(totalSellingValue),
                            subtitle: "\(itemsWithPricing) items with pricing",
                            icon: "tag.circle.fill",
                            color: .green
                        )
                        
                        let potentialProfit = totalSellingValue - totalCostValue
                        ReportSummaryCard(
                            title: "Total Potential Profit",
                            value: formatCurrency(potentialProfit),
                            subtitle: "If all items sold",
                            icon: "chart.line.uptrend.xyaxis.circle.fill",
                            color: .purple
                        )
                    }
                }
                .padding()
                
                // Shopify Section
                if !shopifyItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cart.fill")
                                .foregroundColor(.green)
                            Text("Shopify Inventory")
                                .font(.headline)
                        }
                        
                        VStack(spacing: 8) {
                            MetricRow(
                                label: "Items",
                                value: "\(shopifyItems.count)",
                                icon: "shippingbox"
                            )
                            MetricRow(
                                label: "Cost Value",
                                value: formatCurrency(shopifyCostValue),
                                icon: "dollarsign.circle"
                            )
                            MetricRow(
                                label: "Retail Value",
                                value: formatCurrency(shopifySellingValue),
                                icon: "tag"
                            )
                            MetricRow(
                                label: "Potential Profit",
                                value: formatCurrency(shopifySellingValue - shopifyCostValue),
                                icon: "chart.line.uptrend.xyaxis",
                                valueColor: shopifySellingValue - shopifyCostValue >= 0 ? .green : .red
                            )
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // QuickBooks Section
                if !quickbooksItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.orange)
                            Text("QuickBooks Inventory")
                                .font(.headline)
                        }
                        
                        VStack(spacing: 8) {
                            MetricRow(
                                label: "Items",
                                value: "\(quickbooksItems.count)",
                                icon: "shippingbox"
                            )
                            MetricRow(
                                label: "Cost Value",
                                value: formatCurrency(quickbooksCostValue),
                                icon: "dollarsign.circle"
                            )
                            MetricRow(
                                label: "Wholesale Value",
                                value: formatCurrency(quickbooksSellingValue),
                                icon: "tag"
                            )
                            MetricRow(
                                label: "Potential Profit",
                                value: formatCurrency(quickbooksSellingValue - quickbooksCostValue),
                                icon: "chart.line.uptrend.xyaxis",
                                valueColor: quickbooksSellingValue - quickbooksCostValue >= 0 ? .green : .red
                            )
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Manual/Local Section
                if !manualItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                            Text("Manual Pricing")
                                .font(.headline)
                        }
                        
                        // Check if any items have zero quantity
                        let zeroQtyItems = manualItems.filter { $0.quantity == 0 }
                        if !zeroQtyItems.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(zeroQtyItems.count) manual pricing item(s) have 0 quantity")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("Add quantity to these items to see their value in the report")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        VStack(spacing: 8) {
                            MetricRow(
                                label: "Items",
                                value: "\(manualItems.count)",
                                icon: "shippingbox"
                            )
                            MetricRow(
                                label: "Cost Value",
                                value: formatCurrency(manualCostValue),
                                icon: "dollarsign.circle"
                            )
                            MetricRow(
                                label: "Selling Value",
                                value: formatCurrency(manualSellingValue),
                                icon: "tag"
                            )
                            MetricRow(
                                label: "Potential Profit",
                                value: formatCurrency(manualSellingValue - manualCostValue),
                                icon: "chart.line.uptrend.xyaxis",
                                valueColor: manualSellingValue - manualCostValue >= 0 ? .green : .red
                            )
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("About This Report")
                        .font(.headline)
                    
                    Text("This report shows your inventory value broken down by source: Shopify (retail/online), QuickBooks (wholesale/B2B), and Manual pricing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if itemsWithPricing < totalItems {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(totalItems - itemsWithPricing) items don't have pricing set")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Sync from Shopify/QuickBooks or add manual pricing to get complete calculations")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Inventory Value")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}
