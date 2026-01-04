//
//  ProfitMarginCalculatorView.swift
//  WMS Suite
//
//  Quick profit margin calculator tool
//

import SwiftUI

struct ProfitMarginCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var costText = ""
    @State private var priceText = ""
    @State private var quantityText = "1"
    @State private var calculation = QuickCalculation()
    var isEmbedded: Bool = false  // Track if embedded in navigation
    
    var body: some View {
        Group {
            if isEmbedded {
                calculatorContent
            } else {
                NavigationView {
                    calculatorContent
                }
            }
        }
    }
    
    // MARK: - Calculator Content
    
    private var calculatorContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Calculator icon
                Image(systemName: "function")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                    .padding(.top)
                
                Text("Quick Margin Calculator")
                    .font(.title2)
                    .bold()
                
                Text("Calculate profit margins instantly")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Input section
                VStack(spacing: 16) {
                    // Cost input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cost per Unit")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $costText)
                                .keyboardType(.decimalPad)
                                .onChange(of: costText) { _ in updateCalculation() }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    
                    // Selling price input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selling Price per Unit")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $priceText)
                                .keyboardType(.decimalPad)
                                .onChange(of: priceText) { _ in updateCalculation() }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    
                    // Quantity input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quantity (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("1", text: $quantityText)
                            .keyboardType(.numberPad)
                            .onChange(of: quantityText) { _ in updateCalculation() }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
                
                // Results section
                if calculation.cost > 0 && calculation.sellingPrice > 0 {
                    resultsSection
                }
                
                // Quick tips
                tipsSection
            }
            .padding()
        }
        .navigationTitle("Margin Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEmbedded {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    costText = ""
                    priceText = ""
                    quantityText = "1"
                    calculation = QuickCalculation()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var resultsSection: some View {
        VStack(spacing: 16) {
            // Category indicator
            HStack {
                Image(systemName: calculation.marginCategory.icon)
                    .font(.title2)
                    .foregroundColor(calculation.marginCategory.color)
                
                Text(calculation.marginCategory.rawValue)
                    .font(.title3)
                    .bold()
                    .foregroundColor(calculation.marginCategory.color)
                
                Spacer()
            }
            .padding()
            .background(calculation.marginCategory.color.opacity(0.1))
            .cornerRadius(10)
            
            // Main results
            VStack(spacing: 12) {
                ResultRow(
                    label: "Profit Margin",
                    value: String(format: "%.1f%%", NSDecimalNumber(decimal: calculation.margin).doubleValue),
                    color: calculation.marginCategory.color,
                    isLarge: true
                )
                
                Divider()
                
                ResultRow(
                    label: "Profit per Unit",
                    value: formatCurrency(calculation.profit),
                    color: calculation.profit >= 0 ? .green : .red
                )
                
                ResultRow(
                    label: "Markup",
                    value: String(format: "%.1f%%", NSDecimalNumber(decimal: calculation.markup).doubleValue),
                    color: .blue
                )
                
                if calculation.quantity > 1 {
                    Divider()
                    
                    ResultRow(
                        label: "Total Profit (\(calculation.quantity) units)",
                        value: formatCurrency(calculation.totalProfit),
                        color: calculation.totalProfit >= 0 ? .green : .red,
                        isLarge: true
                    )
                }
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5)
        }
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Quick Tips")
                    .font(.headline)
            }
            
            TipRow(
                icon: "info.circle.fill",
                text: "Profit Margin = (Price - Cost) ÷ Price × 100",
                color: .blue
            )
            
            TipRow(
                icon: "chart.line.uptrend.xyaxis",
                text: "Markup = (Price - Cost) ÷ Cost × 100",
                color: .green
            )
            
            TipRow(
                icon: "star.fill",
                text: "Good margins are typically 20-40% or higher",
                color: .orange
            )
            
            TipRow(
                icon: "exclamationmark.triangle.fill",
                text: "Negative margins mean you're losing money",
                color: .red
            )
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func updateCalculation() {
        let cost = Decimal(string: costText) ?? 0
        let price = Decimal(string: priceText) ?? 0
        let quantity = Int(quantityText) ?? 1
        
        calculation = QuickCalculation(
            cost: cost,
            sellingPrice: price,
            quantity: max(1, quantity)
        )
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

// MARK: - Result Row Component

struct ResultRow: View {
    let label: String
    let value: String
    let color: Color
    var isLarge: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(isLarge ? .headline : .subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(isLarge ? .title2 : .body)
                .bold()
                .foregroundColor(color)
        }
    }
}

// MARK: - Tip Row Component

struct TipRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfitMarginCalculatorView()
}
