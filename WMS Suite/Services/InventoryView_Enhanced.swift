//
//  InventoryView_Enhanced.swift
//  WMS Suite
//
//  Enhanced version with prominent Quick Actions Bar
//  Replace existing InventoryView with this version
//

import SwiftUI
import CoreData

struct InventoryView_Enhanced: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var searchText = ""
    @State private var showingAddItem = false
    @State private var refreshID = UUID()
    
    // Sorting and Filtering
    @State private var selectedSort: InventorySortOption = .nameAZ
    @State private var selectedFilter: InventoryFilterOption = .all
    @State private var selectedTag: ProductTag? = nil
    @State private var showingTagPicker = false
    @StateObject private var tagManager = TagManager.shared
    
    // ⭐ NEW: Quick Action Sheets (now more prominent)
    @State private var showingQuickScan = false
    @State private var showingPutAway = false
    @State private var showingTakeOut = false
    @State private var showingBarcodeGenerator = false
    
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
        items = selectedFilter.filter(items, selectedTag: selectedTag)
        
        // Apply sort
        items = selectedSort.sort(items)
        
        return items
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ⭐ NEW: Prominent Quick Actions Bar (replaces hidden floating button)
                QuickActionsBar(
                    onQuickScan: { showingQuickScan = true },
                    onPutAway: { showingPutAway = true },
                    onTakeOut: { showingTakeOut = true },
                    onPrintLabel: { showingBarcodeGenerator = true }
                )
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // Main content
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
            .loading(viewModel.isLoading, message: "Syncing inventory...")
            .toolbar {
                // LEFT SIDE - Refresh button
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
                    
                    FilterButton(selectedFilter: $selectedFilter, showingTagPicker: $showingTagPicker)
                    SortButton(selectedSort: $selectedSort)
                    
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by name, SKU, or UPC...")
            .sheet(isPresented: $showingAddItem) {
                AddItemView(viewModel: viewModel, isPresented: $showingAddItem)
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerSheet(
                    selectedTag: $selectedTag,
                    selectedFilter: $selectedFilter,
                    isPresented: $showingTagPicker
                )
            }
            .sheet(isPresented: $showingQuickScan) {
                QuickScanView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingPutAway) {
                PutAwayInventoryView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingTakeOut) {
                TakeOutInventoryView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingBarcodeGenerator) {
                BarcodeView(viewModel: viewModel)
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
            // Active filters indicator
            if selectedFilter != .all || selectedSort != .nameAZ {
                ActiveFiltersBar(
                    selectedFilter: $selectedFilter,
                    selectedSort: $selectedSort,
                    selectedTag: selectedTag,
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
            .id(refreshID)
        }
        .onAppear {
            // Only refresh if items array is empty (first load or after clear)
            if viewModel.items.isEmpty {
                print("📱 InventoryView appeared with no items, fetching...")
                viewModel.fetchItems()
            }
            refreshID = UUID()
        }
    }
    
    /// Refresh all data sources
    private func refreshAllData() {
        viewModel.refreshAllData()
    }
    
    /// Async version for pull-to-refresh
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

// MARK: - Migration Instructions

/*
 
 TO MIGRATE FROM OLD InventoryView TO THIS ENHANCED VERSION:
 
 1. Rename your current InventoryView.swift to InventoryView_Old.swift
 
 2. Rename this file (InventoryView_Enhanced.swift) to InventoryView.swift
 
 3. Update the struct name from `InventoryView_Enhanced` to `InventoryView`
 
 4. Test all functionality:
    - Quick Scan button
    - Put Away button
    - Take Out button
    - Print Labels button
    - Search functionality
    - Filter/Sort
    - Add item
    - Delete item
    - Pull to refresh
 
 5. If everything works, delete InventoryView_Old.swift
 
 BENEFITS OF THIS VERSION:
 - ✅ More discoverable actions (no hidden menu)
 - ✅ Consistent with iOS design patterns
 - ✅ Better iPad support
 - ✅ Clearer visual hierarchy
 - ✅ Haptic feedback on buttons
 - ✅ All existing functionality preserved
 
 */

// MARK: - Preview

#Preview("iPhone") {
    let context = PersistenceController.preview.container.viewContext
    let repository = InventoryRepository(context: context)
    let shopifyService = ShopifyService(storeUrl: "test.myshopify.com", accessToken: "test")
    let quickbooksService = QuickBooksService(companyId: "test", accessToken: "test", refreshToken: "test")
    let barcodeService = BarcodeService()
    
    let viewModel = InventoryViewModel(
        repository: repository,
        shopifyService: shopifyService,
        quickbooksService: quickbooksService,
        barcodeService: barcodeService
    )
    
    InventoryView_Enhanced(viewModel: viewModel)
        .environment(\.managedObjectContext, context)
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPad") {
    let context = PersistenceController.preview.container.viewContext
    let repository = InventoryRepository(context: context)
    let shopifyService = ShopifyService(storeUrl: "test.myshopify.com", accessToken: "test")
    let quickbooksService = QuickBooksService(companyId: "test", accessToken: "test", refreshToken: "test")
    let barcodeService = BarcodeService()
    
    let viewModel = InventoryViewModel(
        repository: repository,
        shopifyService: shopifyService,
        quickbooksService: quickbooksService,
        barcodeService: barcodeService
    )
    
    InventoryView_Enhanced(viewModel: viewModel)
        .environment(\.managedObjectContext, context)
        .environment(\.horizontalSizeClass, .regular)
}
