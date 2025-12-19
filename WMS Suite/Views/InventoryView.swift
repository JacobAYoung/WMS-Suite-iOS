//
//  InventoryView.swift
//  WMS Suite
//
//  Main inventory list with sorting and filtering
//

import SwiftUI
import CoreData

struct InventoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var searchText = ""
    @State private var showingAddItem = false
    
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
                // LEFT SIDE - ONLY REFRESH BUTTON
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refreshData) {
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
                
                // RIGHT SIDE - Filter, Sort, Add
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
            // ADD THE SYNC ALERT
            .alert("Sync Status", isPresented: $viewModel.showingSyncAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.syncMessage)
            }
            .onAppear {
                refreshData()
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
        }
    }
    
    private func refreshData() {
        // Call the ACTUAL method that exists in ViewModel
        viewModel.syncWithShopify()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = processedItems[index]
            viewModel.deleteItem(item)
        }
    }
}
