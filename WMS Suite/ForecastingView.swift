//
//  ForecastingView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI

struct ForecastingView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedItem: InventoryItem?
    @State private var forecastDays = 30
    @State private var forecastResult: ForecastResult?
    @State private var isCalculating = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No Inventory Items",
                        systemImage: "tray",
                        description: Text("Add inventory items to view forecasts")
                    )
                } else {
                    Form {
                        Section("Select Item") {
                            Picker("Item", selection: $selectedItem) {
                                Text("Choose an item").tag(nil as InventoryItem?)
                                ForEach(viewModel.items) { item in
                                    Text("\(item.name ?? "Unknown") (\(item.sku ?? ""))").tag(item as InventoryItem?)
                                }
                            }
                        }
                        
                        Section("Forecast Period") {
                            Stepper("Days: \(forecastDays)", value: $forecastDays, in: 7...90, step: 7)
                        }
                        
                        Section {
                            Button(action: calculateForecast) {
                                HStack {
                                    Spacer()
                                    if isCalculating {
                                        ProgressView()
                                            .padding(.trailing, 8)
                                    }
                                    Text("Calculate Forecast")
                                    Spacer()
                                }
                            }
                            .disabled(selectedItem == nil || isCalculating)
                        }
                        
                        if let result = forecastResult {
                            Section("Forecast Results") {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .foregroundColor(.blue)
                                        Text("Average Daily Sales")
                                        Spacer()
                                        Text(String(format: "%.2f units/day", result.averageDailySales))
                                            .bold()
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.purple)
                                        Text("Projected Sales (\(forecastDays)d)")
                                        Spacer()
                                        Text("\(result.projectedSales) units")
                                            .bold()
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(result.daysUntilStockout < 7 ? .red : .orange)
                                        Text("Days Until Stockout")
                                        Spacer()
                                        Text("\(result.daysUntilStockout) days")
                                            .bold()
                                            .foregroundColor(result.daysUntilStockout < 7 ? .red : .primary)
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Image(systemName: "shippingbox")
                                            .foregroundColor(.green)
                                        Text("Recommended Order")
                                        Spacer()
                                        Text("\(result.recommendedOrderQuantity) units")
                                            .bold()
                                            .foregroundColor(.green)
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("Data Sources")
                                        Spacer()
                                    }
                                    
                                    HStack {
                                        ForEach(result.item.itemSources, id: \.self) { source in
                                            HStack(spacing: 4) {
                                                Image(systemName: source.iconName)
                                                Text(source.rawValue)
                                            }
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(source.color.opacity(0.2))
                                            .foregroundColor(source.color)
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            
                            Section("Current Status") {
                                HStack {
                                    Text("Current Stock")
                                    Spacer()
                                    Text("\(result.item.quantity) units")
                                        .foregroundColor(.secondary)
                                }
                                
                                if result.item.minStockLevel > 0 {
                                    HStack {
                                        Text("Min Stock Level")
                                        Spacer()
                                        Text("\(result.item.minStockLevel) units")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Section("Recommendations") {
                                VStack(alignment: .leading, spacing: 8) {
                                    if result.daysUntilStockout < 7 {
                                        Label("⚠️ Critical: Order immediately to avoid stockout", systemImage: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                    } else if result.daysUntilStockout < 14 {
                                        Label("⚠️ Warning: Consider placing order soon", systemImage: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                    } else {
                                        Label("✓ Stock levels adequate for forecast period", systemImage: "checkmark.circle")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Forecasting")
        }
    }
    
    private func calculateForecast() {
        guard let item = selectedItem else { return }
        isCalculating = true
        
        Task {
            forecastResult = await viewModel.calculateForecast(for: item, days: forecastDays)
            isCalculating = false
        }
    }
}
