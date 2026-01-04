//
//  InventoryView.swift
//  WMS Suite
//
//  Updated: Enhanced with Quick Actions (Scan, Put Away, Take Out)
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
    @State private var selectedTag: ProductTag? = nil
    @State private var showingTagPicker = false
    @StateObject private var tagManager = TagManager.shared
    
    // ⭐ NEW: Quick Action Sheets
    @State private var showingQuickScan = false
    @State private var showingPutAway = false
    @State private var showingTakeOut = false
    
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
                
                // ⭐ NEW: Floating Quick Actions Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        quickActionsMenu
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Inventory")
            .loading(viewModel.isLoading, message: "Syncing inventory...")
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
                    
                    FilterButton(selectedFilter: $selectedFilter, showingTagPicker: $showingTagPicker)
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
    
    // ⭐ NEW: Quick Actions Floating Menu
    private var quickActionsMenu: some View {
        Menu {
            Button(action: { showingQuickScan = true }) {
                Label("Quick Scan", systemImage: "barcode.viewfinder")
            }
            
            Divider()
            
            Button(action: { showingPutAway = true }) {
                Label("Put Away", systemImage: "arrow.down.to.line.compact")
            }
            
            Button(action: { showingTakeOut = true }) {
                Label("Take Out", systemImage: "arrow.up.from.line")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var inventoryList: some View {
        VStack(spacing: 0) {
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
            .id(refreshID)  // Force list to rebuild when this changes
        }
        .onAppear {
            // Only refresh if items array is empty (first load or after clear)
            // ViewModel already loads data in init(), so this prevents double-loading
            if viewModel.items.isEmpty {
                print("📱 InventoryView appeared with no items, fetching...")
                viewModel.fetchItems()
            }
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

// MARK: - Tag Picker Sheet

struct TagPickerSheet: View {
    @Binding var selectedTag: ProductTag?
    @Binding var selectedFilter: InventoryFilterOption
    @Binding var isPresented: Bool
    @StateObject private var tagManager = TagManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        selectedTag = nil
                        selectedFilter = .all
                        isPresented = false
                    }) {
                        HStack {
                            Text("All Items")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTag == nil && selectedFilter == .all {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } header: {
                    Text("Clear Filter")
                }
                
                if tagManager.availableTags.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "tag")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No tags created yet")
                                .font(.headline)
                            Text("Create tags to organize your inventory")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                } else {
                    Section {
                        ForEach(tagManager.availableTags) { tag in
                            Button(action: {
                                selectedTag = tag
                                selectedFilter = .byTag
                                isPresented = false
                            }) {
                                HStack {
                                    TagBadge(tag: tag)
                                    Spacer()
                                    if selectedTag?.id == tag.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Filter by Tag")
                    }
                }
            }
            .navigationTitle("Select Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

