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
                    NavigationLink(destination: BarcodeView(viewModel: viewModel)) {
                        ToolRow(
                            icon: "barcode.viewfinder",
                            title: "Barcode Scanner",
                            description: "Scan product barcodes",
                            color: .blue,
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
                    Text("Analytics & Reports")
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
