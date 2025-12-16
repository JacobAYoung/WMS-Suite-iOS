//
//  InventoryView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI

struct InventoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showingAddItem = false
    @State private var showingScanner = false
    @State private var searchText = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var filteredItems: [InventoryItem] {
        if searchText.isEmpty {
            return viewModel.items
        }
        return viewModel.items.filter { item in
            (item.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (item.sku?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    // Detect if we're on iPad
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else {
                    // Use grid for iPad, list for iPhone
                    if isIPad {
                        InventoryGridView(viewModel: viewModel, items: filteredItems)
                    } else {
                        List {
                            ForEach(filteredItems) { item in
                                NavigationLink(destination: ProductDetailView(viewModel: viewModel, item: item)) {
                                    InventoryRow(item: item)
                                }
                            }
                            .onDelete { indexSet in
                                deleteItems(at: indexSet)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search SKU or Name")
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: { viewModel.syncWithShopify() }) {
                            Label("Sync", systemImage: viewModel.isLoading ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath")
                        }
                        .disabled(viewModel.isLoading)
                        
                        Button(action: { showingScanner = true }) {
                            Label("Scan", systemImage: "barcode.viewfinder")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(viewModel: viewModel, isPresented: $showingAddItem)
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView(viewModel: viewModel)
            }
            .alert("Sync Status", isPresented: $viewModel.showingSyncAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.syncMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteItem(filteredItems[index])
        }
    }
}
