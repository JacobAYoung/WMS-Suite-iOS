//
//  InventoryView.swift
//  WMS Suite
//
//  Updated: Refresh button now syncs all sources (Local, Shopify, QuickBooks)
//

import SwiftUI
import CoreData

struct InventoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var searchText = ""
    @State private var showingAddItem = false
    @State private var refreshID = UUID()  // ✅ NEW: Force view refresh
    
    // Sorting and Filtering
    @State private var selectedSort: InventorySortOption = .nameAZ
    @State private var selectedFilter: InventoryFilterOption = .all
    
    // Computed filtered and sorted items
    var processedItems: [InventoryItem] {
        var items = viewModel.items
        
        // Apply search
        if !searchText.isEmpty {
            items = items.filter { item in
                (item.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.sku?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.upc?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply filter
        items = selectedFilter.filter(items)
        
        // Apply sort
        items = selectedSort.sort(items)
        
        return items
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if processedItems.isEmpty {
                    EmptyStateView(
                        searchText: searchText,
                        selectedFilter: $selectedFilter,
                        showingAddItem: $showingAddItem
                    )
                } else {
                    inventoryList
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                // LEFT SIDE - Refresh button (now syncs all sources)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refreshAllData) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
                
                // RIGHT SIDE - Charts, Filter, Sort, Add
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Charts navigation link
                    NavigationLink(destination: ProductsChartsView()) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.blue)
                    }
                    
                    FilterButton(selectedFilter: $selectedFilter)
                    SortButton(selectedSort: $selectedSort)
                    
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search items...")
            .sheet(isPresented: $showingAddItem) {
                AddItemView(viewModel: viewModel, isPresented: $showingAddItem)
            }
            .alert("Sync Status", isPresented: $viewModel.showingSyncAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.syncMessage)
            }
            .refreshable {
                await refreshAllDataAsync()
            }
        }
    }
    
    private var inventoryList: some View {
        VStack(spacing: 0) {
            if selectedFilter != .all || selectedSort != .nameAZ {
                ActiveFiltersBar(
                    selectedFilter: $selectedFilter,
                    selectedSort: $selectedSort,
                    itemCount: processedItems.count
                )
            }
            
            List {
                ForEach(processedItems) { item in
                    NavigationLink(destination: ProductDetailView(viewModel: viewModel, item: item)) {
                        InventoryRow(item: item)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .id(refreshID)  // ✅ NEW: Force list to rebuild when this changes
        }
        .onAppear {
            // ✅ NEW: Refresh when view appears (e.g., navigating back)
            print("📱 InventoryView appeared, refreshing...")
            viewModel.fetchItems()
            refreshID = UUID()
        }
    }
    
    /// ✅ UPDATED: Now refreshes ALL sources (Local, Shopify, QuickBooks)
    private func refreshAllData() {
        viewModel.refreshAllData()
    }
    
    /// ✅ UPDATED: Async version for pull-to-refresh
    private func refreshAllDataAsync() async {
        viewModel.refreshAllData()
        
        // Wait for loading to complete
        while viewModel.isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = processedItems[index]
            viewModel.deleteItem(item)
        }
    }
}
