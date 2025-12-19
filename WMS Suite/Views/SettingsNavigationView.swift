//
//  SettingsNavigationView.swift
//  WMS Suite
//
//  Updated with dynamic version/build numbers
//

import SwiftUI

struct SettingsNavigationView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showingClearDataAlert = false
    
    // Read version/build from Info.plist
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
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
                    
                    NavigationLink(destination: QuickBooksSettingsView()) {
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
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
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
