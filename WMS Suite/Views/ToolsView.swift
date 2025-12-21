//
//  ToolsView.swift
//  WMS Suite
//
//  Consolidated utilities view for barcode scanning and AI counting
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
                            color: .blue
                        )
                    }
                    
                    NavigationLink(destination: CountingView(viewModel: viewModel)) {
                        ToolRow(
                            icon: "camera.viewfinder",
                            title: "AI Counter",
                            description: "Count items with camera",
                            color: .green
                        )
                    }
                } header: {
                    Text("Inventory Tools")
                }
                
                Section {
                    NavigationLink(destination: ProductsChartsView()) {
                        ToolRow(
                            icon: "chart.bar.fill",
                            title: "Product Analytics",
                            description: "View product trends and insights",
                            color: .purple
                        )
                    }
                    
                    NavigationLink(destination: OrdersChartsView()) {
                        ToolRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Order Analytics",
                            description: "Track order performance",
                            color: .orange
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
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
