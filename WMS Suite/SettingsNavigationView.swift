//
//  SettingsNavigationView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import SwiftUI

struct SettingsNavigationView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showingClearDataAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Integrations") {
                    NavigationLink(destination: ShopifySettingsView()) {
                        HStack {
                            Image(systemName: "cart.fill")
                                .foregroundColor(.green)
                                .frame(width: 30)
                            Text("Shopify Integration")
                        }
                    }
                    
                    NavigationLink(destination: QuickBooksSettingsView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            Text("QuickBooks Integration")
                        }
                    }
                }
                
                Section("Data Management") {
                    NavigationLink(destination: DataManagementView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("Import/Export Data")
                        }
                    }
                    
                    Button(role: .destructive, action: { showingClearDataAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .frame(width: 30)
                            Text("Clear All Data")
                            Spacer()
                        }
                    }
                }
                
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("100")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Items")
                        Spacer()
                        Text("\(viewModel.items.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all inventory data. This action cannot be undone.")
            }
        }
    }
    
    private func clearAllData() {
        for item in viewModel.items {
            viewModel.deleteItem(item)
        }
    }
}
