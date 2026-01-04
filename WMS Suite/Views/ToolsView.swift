//
//  ToolsView.swift
//  WMS Suite
//
//  Updated: AI Counter temporarily disabled
//

import SwiftUI

struct ToolsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: BarcodeToolsView(viewModel: viewModel)) {
                        ToolRow(
                            icon: "barcode.viewfinder",
                            title: "Barcode Tools",
                            description: "Scan & generate barcodes",
                            color: .blue,
                            isEnabled: true
                        )
                    }
                    
                    // ⭐ UPDATED: Profit Margin Calculator as NavigationLink
                    NavigationLink(destination: ProfitMarginCalculatorView(isEmbedded: true)) {
                        ToolRow(
                            icon: "function",
                            title: "Margin Calculator",
                            description: "Quick profit margin calculator",
                            color: .green,
                            isEnabled: true
                        )
                    }
                    
                    // ✅ DISABLED: AI Counter
                    HStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.gray)
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("AI Counter")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("(Coming Soon)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            Text("Count items with camera - Currently being improved")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .opacity(0.6)
                    
                } header: {
                    Text("Inventory Tools")
                }
                
                Section {
                    NavigationLink(destination: ReportsView(viewModel: viewModel)) {
                        ToolRow(
                            icon: "doc.text.fill",
                            title: "Reports",
                            description: "Inventory value, margins, and analytics",
                            color: .green,
                            isEnabled: true
                        )
                    }
                } header: {
                    Text("Reports & Analytics")
                }
                
                Section {
                    NavigationLink(destination: ProductsChartsView()) {
                        ToolRow(
                            icon: "chart.bar.fill",
                            title: "Product Analytics",
                            description: "View product trends and insights",
                            color: .purple,
                            isEnabled: true
                        )
                    }
                    
                    NavigationLink(destination: OrdersChartsView()) {
                        ToolRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Order Analytics",
                            description: "Track order performance",
                            color: .orange,
                            isEnabled: true
                        )
                    }
                } header: {
                    Text("Charts & Visualizations")
                }
            }
            .navigationTitle("Tools & Utilities")
        }
    }
}

// MARK: - Tool Row Component

struct ToolRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var isEnabled: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(isEnabled ? color : Color.gray)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}
