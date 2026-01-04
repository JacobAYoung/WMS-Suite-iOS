//
//  BarcodeToolsView.swift
//  WMS Suite
//
//  Combined barcode scanning and generation tool
//

import SwiftUI

struct BarcodeToolsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedTab: ToolTab = .scan
    
    enum ToolTab: String, CaseIterable {
        case scan = "Scan"
        case generate = "Generate"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Tool", selection: $selectedTab) {
                ForEach(ToolTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            switch selectedTab {
            case .scan:
                BarcodeScannerView(viewModel: viewModel, isEmbedded: true)
            case .generate:
                BarcodeView(viewModel: viewModel)
            }
        }
        .navigationTitle("Barcode Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}
