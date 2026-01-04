//
//  ProductDetailView.swift
//  WMS Suite
//
//  FIXED: Explicitly refreshes ViewModel when returning from EditItemView
//

import SwiftUI
import CoreData

struct ProductDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: InventoryViewModel
    let item: InventoryItem
    
    @State private var showingEditItem = false
    @State private var showingAddSale = false
    @State private var showingPushConfirmation = false
    @State private var pushTarget: ItemSource?
    @State private var salesHistory: [SalesHistoryDisplay] = []
    @State private var showingForecastDetail = false
    @State private var quickForecast: ForecastResult?
    @State private var refreshTrigger = UUID()  // ✅ NEW: Force view refresh
    @State private var showingNotesTagsView = false  // ⭐ NEW: For sheet presentation
    @State private var showingEditPricing = false  // ⭐ NEW: For pricing editor
    @State private var reorderRecommendation: ReorderRecommendation? // ⭐ NEW: For reorder alerts
    @State private var isLoadingSalesHistory = false // 📊 NEW: Loading state
    @State private var isPushingToService = false // 🔄 NEW: Push loading state
    
    // ⚡ PERFORMANCE: Cache pricing data to avoid repeated UserDefaults lookups
    @State private var cachedCost: Decimal = 0
    @State private var cachedSellingPrice: Decimal? = nil
    @State private var cachedPriceSource: String? = nil
    @State private var isPricingLoaded = false  // Track loading state
    
    // MARK: - Computed Properties
    
    private var loadingMessage: String {
        if isPushingToService {
            return "Syncing to \(pushTarget?.rawValue.capitalized ?? "service")..."
        } else if isLoadingSalesHistory {
            return "Loading sales history..."
        }
        return "Loading..."
    }
    
    private var canSyncToShopify: Bool {
        let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? ""
        let accessToken = UserDefaults.standard.string(forKey: "shopifyAccessToken") ?? ""
        
        guard !storeUrl.isEmpty && !accessToken.isEmpty else {
            return false
        }
        
        let canWrite = UserDefaults.standard.bool(forKey: "shopify_canWriteInventory")
        return canWrite
    }
    
    private var shopifyConfigured: Bool {
        let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? ""
        let accessToken = UserDefaults.standard.string(forKey: "shopifyAccessToken") ?? ""
        return !storeUrl.isEmpty && !accessToken.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                productImageSection
                headerSection
                
                // Reorder Alert (if needed)
                if let recommendation = reorderRecommendation {
                    reorderAlertSection(recommendation)
                }
                
                productInfoSection
                inventoryBySourceSection
                pricingSection
                tagsNotesSection
                actionButtonsSection
                forecastSection
                salesHistorySection
            }
            .padding(.vertical)
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshTrigger)  // ✅ NEW: Force view to rebuild when this changes
        .loading(isLoadingSalesHistory || isPushingToService, message: loadingMessage)
        .task {
            // ✅ Use .task instead of .onAppear for async work
            // This doesn't block the UI
            await loadDataAsync()
        }
        // ✅ UPDATED: Refresh when returning from sheets
        .onChange(of: showingAddSale) { isShowing in
            if !isShowing {
                // Sheet was dismissed, refresh data
                loadSalesHistory()
                loadQuickForecast()
                checkReorderStatus() // ⭐ Also refresh reorder status
                // Force ViewModel to reload items list
                viewModel.fetchItems()
            }
        }
        .onChange(of: showingEditItem) { isShowing in
            if !isShowing {
                // ✅ CRITICAL: Force complete refresh when edit sheet closes
                print("🔄 EditItemView closed, refreshing data...")
                loadSalesHistory()
                checkReorderStatus() // ⭐ Also refresh reorder status
                // Force ViewModel to reload items from database
                viewModel.fetchItems()
                // Force this view to rebuild
                refreshTrigger = UUID()
            }
        }
        .sheet(isPresented: $showingEditItem) {
            EditItemView(viewModel: viewModel, item: item, isPresented: $showingEditItem)
        }
        .sheet(isPresented: $showingAddSale) {
            AddSalesView(preselectedItem: item)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingForecastDetail) {
            ForecastDetailView(viewModel: viewModel, item: item)
        }
        .sheet(isPresented: $showingNotesTagsView) {
            NavigationView {
                ProductNotesTagsView(item: item)
            }
        }
        .sheet(isPresented: $showingEditPricing) {
            EditPricingView(
                onSave: { cost, price in
                    // Save on main context
                    item.cost = cost
                    if let price = price {
                        item.sellingPrice = price
                    } else {
                        item.sellingPrice = nil
                    }
                    
                    // Update cached values immediately
                    cachedCost = cost
                    cachedSellingPrice = price
                    cachedPriceSource = item.priceSource
                    
                    // Save context
                    do {
                        try viewContext.save()
                    } catch {
                        print("❌ Failed to save pricing: \(error)")
                    }
                },
                initialData: PricingData(
                    cost: cachedCost,
                    sellingPrice: cachedSellingPrice,
                    shopifyPrice: item.shopifyPrice,
                    quickbooksPrice: item.quickbooksPrice,
                    sku: item.sku ?? ""
                )
            )
        }
        .onChange(of: showingNotesTagsView) { isShowing in
            if !isShowing {
                // ⭐ Force refresh when notes/tags sheet closes
                refreshTrigger = UUID()
            }
        }
        .onChange(of: showingEditPricing) { isShowing in
            if !isShowing {
                // ⭐ Force refresh when pricing sheet closes
                refreshTrigger = UUID()
            }
        }
        .alert("Push to \(pushTarget?.rawValue ?? "")?", isPresented: $showingPushConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Push") {
                if let target = pushTarget {
                    pushToService(target)
                }
            }
        } message: {
            if let target = pushTarget {
                Text("This will \(item.existsIn(target) ? "update" : "create") this item in \(target.rawValue).")
            }
        }
    }
    
    // MARK: - View Components
    
    private var productImageSection: some View {
        Group {
            if let imageUrl = item.displayImageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .cornerRadius(12)
                    case .failure:
                        placeholderImage
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
            } else {
                placeholderImage
                    .padding(.horizontal)
            }
        }
    }
    
    private var placeholderImage: some View {
        Image(systemName: "photo")
            .font(.system(size: 60))
            .foregroundColor(.gray)
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(item.name ?? "Unknown Item")
                .font(.title)
                .bold()
            
            HStack(spacing: 8) {
                ForEach(item.itemSources, id: \.self) { source in
                    HStack(spacing: 4) {
                        Image(systemName: source.iconName)
                        Text(source.rawValue)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(source.color.opacity(0.2))
                    .foregroundColor(source.color)
                    .cornerRadius(15)
                }
            }
            
            if item.needsShopifySync || item.needsQuickBooksSync {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Needs Sync")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var productInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Product Information")
                .font(.headline)
            
            InfoRow(label: "SKU", value: item.sku ?? "N/A")
            
            if let webSKU = item.webSKU, !webSKU.isEmpty {
                InfoRow(label: "Web SKU", value: webSKU)
            }
            
            if let upc = item.upc, !upc.isEmpty {
                InfoRow(label: "UPC", value: upc)
            }
            
            InfoRow(label: "Quantity", value: "\(item.quantity)")
            
            // Convert minStockLevel to Decimal for comparison
            let minStock: Decimal
            if let decimalNumber = item.minStockLevel as? NSDecimalNumber {
                minStock = decimalNumber.decimalValue
            } else if let decimal = item.minStockLevel as? Decimal {
                minStock = decimal
            } else {
                minStock = 0
            }
            
            if minStock > 0 {
                InfoRow(label: "Min Stock Level", value: "\(item.minStockLevel ?? 0)")
            }
            
            if let description = item.itemDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(description)
                        .font(.body)
                }
            }
            
            if let lastUpdated = item.lastUpdated {
                InfoRow(label: "Last Updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
        .padding(.horizontal)
    }
    
    // ⭐ NEW: Inventory by Source Section
    private var inventoryBySourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory by Source")
                .font(.headline)
            
            // Local Inventory (always present)
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: ItemSource.local.iconName)
                        .foregroundColor(ItemSource.local.color)
                    Text("Local")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                Text("\(item.quantity) units")
                    .font(.subheadline)
                    .bold()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            // QuickBooks Inventory
            if item.existsIn(.quickbooks) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: ItemSource.quickbooks.iconName)
                            .foregroundColor(ItemSource.quickbooks.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("QuickBooks")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let lastSync = item.lastSyncedQuickbooksDate {
                                Text("Synced \(lastSync, style: .relative) ago")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.quantity) units")
                            .font(.subheadline)
                            .bold()
                        if item.needsQuickBooksSync {
                            Label("Needs Sync", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Shopify Inventory
            if item.existsIn(.shopify) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: ItemSource.shopify.iconName)
                            .foregroundColor(ItemSource.shopify.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shopify")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let lastSync = item.lastSyncedShopifyDate {
                                Text("Synced \(lastSync, style: .relative) ago")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.quantity) units")
                            .font(.subheadline)
                            .bold()
                        if item.needsShopifySync {
                            Label("Needs Sync", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Help text
            Text("Quantities shown reflect the current inventory count. Use sync buttons below to update each platform.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
        .padding(.horizontal)
    }
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Pricing & Cost")
                    .font(.headline)
                Spacer()
                
                Button(action: { showingEditPricing = true }) {
                    HStack {
                        Text("Edit")
                        Image(systemName: "pencil")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .disabled(!isPricingLoaded)  // Disable until loaded
            }
            
            if isPricingLoaded {
                // Show actual pricing data
                pricingContent
            } else {
                // Show loading skeleton
                pricingLoadingSkeleton
            }
            
            Text("Sync from Shopify to get selling prices automatically")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var pricingContent: some View {
        VStack(spacing: 12) {
            // ⭐ Primary Pricing (What's Currently Used)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if cachedCost > 0 {
                        Text(formatCurrency(cachedCost))
                            .font(.title3)
                            .bold()
                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Selling Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let source = cachedPriceSource {
                            Text("(\(source))")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    if let price = cachedSellingPrice {
                        Text(formatCurrency(price))
                            .font(.title3)
                            .bold()
                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(8)
            
            // ⭐ NEW: Pricing by Source
            VStack(alignment: .leading, spacing: 8) {
                Text("Pricing by Source")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // QuickBooks Pricing
                let qbCost = item.quickbooksCost
                if qbCost > 0 {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("QuickBooks Cost")
                                .font(.caption)
                        }
                        Spacer()
                        Text(formatCurrency(qbCost))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                }
                
                if let qbPrice = item.quickbooksPrice, qbPrice > 0 {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("QuickBooks Price")
                                .font(.caption)
                        }
                        Spacer()
                        Text(formatCurrency(qbPrice))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                }
                
                // Shopify Pricing
                if let shopifyPrice = item.shopifyPrice, shopifyPrice > 0 {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "cart.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Shopify Price")
                                .font(.caption)
                        }
                        Spacer()
                        Text(formatCurrency(shopifyPrice))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                }
                
                // Show message if no synced prices
                if item.quickbooksCost == 0 &&
                   (item.quickbooksPrice == nil || item.quickbooksPrice == 0) &&
                   (item.shopifyPrice == nil || item.shopifyPrice == 0) {
                    Text("No synced pricing data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            // Show margin if both are set
            if cachedCost > 0, let price = cachedSellingPrice, price > 0 {
                let margin = ((price - cachedCost) / price) * 100
                HStack {
                    Text("Profit Margin:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", NSDecimalNumber(decimal: margin).doubleValue))
                        .font(.headline)
                        .foregroundColor(margin < 0 ? .red : (margin < 20 ? .orange : .green))
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var pricingLoadingSkeleton: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cost")
                    .font(.caption)
                    .foregroundColor(.secondary)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .frame(height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Selling Price")
                    .font(.caption)
                    .foregroundColor(.secondary)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var tagsNotesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tags & Notes")
                    .font(.headline)
                Spacer()
                Button(action: { showingNotesTagsView = true }) {
                    HStack {
                        Text("Manage")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            // Tags
            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(item.tags) { tag in
                            TagBadge(tag: tag)
                        }
                    }
                }
            }
            
            // Recent notes
            if let lastNote = item.notes.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lastNote.text)
                        .font(.body)
                        .lineLimit(2)
                    
                    Text(lastNote.createdDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
            }
            
            if item.tags.isEmpty && item.notes.isEmpty {
                Text("No tags or notes yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: { showingEditItem = true }) {
                ActionButtonContent(icon: "pencil", text: "Edit Item", color: .blue)
            }
            
            Button(action: { showingAddSale = true }) {
                ActionButtonContent(icon: "chart.line.uptrend.xyaxis", text: "Add Sale", color: .green)
            }
            
            shopifySyncButton
            
            Button(action: {
                pushTarget = .quickbooks
                showingPushConfirmation = true
            }) {
                HStack {
                    Image(systemName: "book.fill")
                    Text(item.existsIn(.quickbooks) ? "Update in QuickBooks" : "Push to QuickBooks")
                    Spacer()
                    if item.needsQuickBooksSync {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var shopifySyncButton: some View {
        Group {
            if !shopifyConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Shopify Not Configured", systemImage: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text("Configure Shopify to enable inventory sync")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    NavigationLink(destination: ShopifySettingsView()) {
                        Text("Go to Shopify Settings")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            } else if canSyncToShopify {
                Button(action: {
                    pushTarget = .shopify
                    showingPushConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text(item.existsIn(.shopify) ? "Update in Shopify" : "Push to Shopify")
                        Spacer()
                        if item.needsShopifySync {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }
                
                if let lastSync = item.lastSyncedShopifyDate {
                    Text("Last synced: \(lastSync, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Write Permission Required")
                            .font(.headline)
                    }
                    
                    Text("Your Shopify access token doesn't have write_inventory permission enabled.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("To enable inventory sync:")
                        .font(.caption)
                        .bold()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Go to Shopify Admin → Apps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("2. Your app → Configuration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("3. Enable 'write_inventory' scope")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("4. Reinstall the app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let storeUrl = UserDefaults.standard.string(forKey: "shopifyStoreUrl"),
                       let accessToken = UserDefaults.standard.string(forKey: "shopifyAccessToken") {
                        NavigationLink(destination: ShopifyPermissionsView(storeUrl: storeUrl, accessToken: accessToken)) {
                            Label("Check All Permissions", systemImage: "checkmark.shield")
                                .font(.subheadline)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    private var forecastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Forecast")
                    .font(.headline)
                Spacer()
                Button(action: { showingForecastDetail = true }) {
                    HStack {
                        Text("View Details")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            if let forecast = quickForecast {
                VStack(spacing: 8) {
                    HStack {
                        Text("Avg Daily Sales:")
                        Spacer()
                        Text(String(format: "%.1f units/day", forecast.averageDailySales))
                            .bold()
                    }
                    
                    HStack {
                        Text("Days Until Stockout:")
                        Spacer()
                        Text("\(forecast.daysUntilStockout) days")
                            .bold()
                            .foregroundColor(forecast.daysUntilStockout < 7 ? .red : .primary)
                    }
                }
                .font(.subheadline)
            } else {
                VStack {
                    Text("No sales data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingForecastDetail = true }) {
                        Text("View Forecast Details")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var salesHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sales History")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSale = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Sale")
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                }
            }
            
            if salesHistory.isEmpty {
                VStack(spacing: 8) {
                    Text("No sales recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingAddSale = true }) {
                        Text("Record First Sale")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ForEach(salesHistory.prefix(5)) { sale in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(sale.quantity) units")
                                .font(.headline)
                            
                            if let date = sale.saleDate {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let orderNum = sale.orderNumber, !orderNum.isEmpty {
                                HStack(spacing: 4) {
                                    // ⭐ NEW: Show source icon
                                    if orderNum.contains("#") {
                                        // Shopify orders typically have "#" prefix
                                        Image(systemName: "cart.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text("Shopify")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    } else if orderNum.hasPrefix("QB") || orderNum.count <= 4 {
                                        // QuickBooks orders are usually short numbers
                                        Image(systemName: "book.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text("QuickBooks")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    } else {
                                        Image(systemName: "iphone")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text("Local")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text("• Order: \(orderNum)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "cart.fill")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                if salesHistory.count > 5 {
                    Text("Showing 5 of \(salesHistory.count) sales")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    // ⭐ NEW: Reorder Alert Section
    private func reorderAlertSection(_ recommendation: ReorderRecommendation) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: recommendation.reason.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reorder Recommended")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(recommendation.reason.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(recommendation.priority.displayName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Stock")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(recommendation.currentStock)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Order")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(recommendation.recommendedOrderQuantity)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            
            if recommendation.daysOfStockRemaining <= 7 {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.white)
                    Text("\(recommendation.daysOfStockRemaining) days of stock remaining")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [recommendation.priority.color, recommendation.priority.color.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: recommendation.priority.color.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    // ✅ NEW: Async data loading - doesn't block UI
    private func loadDataAsync() async {
        // Load pricing data on background thread (even though it's UserDefaults, it's good practice)
        let (cost, price, source) = await Task.detached(priority: .userInitiated) {
            return (
                self.item.cost,
                self.item.sellingPrice,
                self.item.priceSource
            )
        }.value
        
        // Update UI on main thread
        await MainActor.run {
            cachedCost = cost
            cachedSellingPrice = price
            cachedPriceSource = source
            isPricingLoaded = true
        }
        
        // Load sales history in background
        await loadSalesHistoryAsync()
        
        // These are async and won't block
        loadQuickForecast()
        checkReorderStatus()
    }
    
    // ✅ IMPROVED: Make sales history loading async
    private func loadSalesHistoryAsync() async {
        isLoadingSalesHistory = true
        defer { isLoadingSalesHistory = false }
        
        // Get item's object ID on main thread
        let itemObjectID = item.objectID
        
        let history = await Task.detached(priority: .userInitiated) {
            // Fetch on background context
            let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
            
            return await backgroundContext.perform {
                // Get the item in background context
                guard let backgroundItem = try? backgroundContext.existingObject(with: itemObjectID) as? InventoryItem else {
                    return [SalesHistoryDisplay]()
                }
                
                let sales = Sale.fetchSales(for: backgroundItem, context: backgroundContext)
                
                return sales.compactMap { sale in
                    guard let lineItems = sale.lineItems as? Set<SaleLineItem>,
                          let lineItem = lineItems.first(where: { $0.item?.objectID == itemObjectID }) else {
                        return nil
                    }
                    
                    return SalesHistoryDisplay(
                        saleDate: sale.saleDate,
                        orderNumber: sale.orderNumber,
                        quantity: {
                            // Convert NSDecimalNumber? to Int32
                            if let decimalNumber = lineItem.quantity as? NSDecimalNumber {
                                return Int32(truncating: decimalNumber)
                            } else if let decimal = lineItem.quantity as? Decimal {
                                return Int32(truncating: NSDecimalNumber(decimal: decimal))
                            }
                            return 0
                        }()
                    )
                }
            }
        }.value
        
        await MainActor.run {
            self.salesHistory = history
        }
    }
    
    // ✅ LEGACY: Keep for sync calls from onChange
    private func loadSalesHistory() {
        Task {
            await loadSalesHistoryAsync()
        }
    }
    
    private func loadQuickForecast() {
        Task {
            quickForecast = await viewModel.calculateForecast(for: item, days: 30)
        }
    }
    
    // ⭐ NEW: Check if item needs reordering
    private func checkReorderStatus() {
        Task {
            // Fetch sales history
            let salesHistoryForItem: [SalesHistoryDisplay]
            do {
                salesHistoryForItem = try await viewModel.shopifyService.fetchRecentSales(for: item)
            } catch {
                print("Failed to fetch sales history for reorder check: \(error)")
                salesHistoryForItem = []
            }
            
            // Generate recommendations
            let recommendations = ReorderRecommendationService.generateRecommendations(
                for: [item],
                salesHistory: [item.sku ?? "": salesHistoryForItem],
                leadTimeDays: 7
            )
            
            await MainActor.run {
                reorderRecommendation = recommendations.first
            }
        }
    }
    
    private func pushToService(_ service: ItemSource) {
        isPushingToService = true
        pushTarget = service
        
        Task {
            defer {
                Task { @MainActor in
                    isPushingToService = false
                    pushTarget = nil
                }
            }
            
            do {
                switch service {
                case .shopify:
                    try await viewModel.pushToShopify(item: item)
                case .quickbooks:
                    try await viewModel.pushToQuickBooks(item: item)
                case .local:
                    break
                }
                
                // Show success feedback
                await MainActor.run {
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    print("Error pushing to \(service.rawValue): \(error)")
                    
                    // Haptic feedback for error
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

// MARK: - Edit Pricing View

// Simple data structure to avoid Core Data threading issues
struct PricingData {
    var cost: Decimal
    var sellingPrice: Decimal?
    var shopifyPrice: Decimal?
    var quickbooksPrice: Decimal?
    var sku: String
}

struct EditPricingView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Decimal, Decimal?) -> Void
    let initialData: PricingData
    
    @State private var costText: String = ""
    @State private var sellingPriceText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Cost")
                            .frame(width: 100, alignment: .leading)
                        Text("$")
                        TextField("0.00", text: $costText)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Selling Price")
                            .frame(width: 100, alignment: .leading)
                        Text("$")
                        TextField("0.00", text: $sellingPriceText)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Manual Pricing")
                } footer: {
                    Text("Manual prices override Shopify/QuickBooks prices")
                }
                
                // Show current auto prices (from cached data)
                Section {
                    if let price = initialData.shopifyPrice {
                        HStack {
                            Text("Shopify Price")
                            Spacer()
                            Text("$\(NSDecimalNumber(decimal: price).doubleValue, specifier: "%.2f")")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let price = initialData.quickbooksPrice {
                        HStack {
                            Text("QuickBooks Price")
                            Spacer()
                            Text("$\(NSDecimalNumber(decimal: price).doubleValue, specifier: "%.2f")")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if initialData.shopifyPrice == nil && initialData.quickbooksPrice == nil {
                        Text("No prices synced from Shopify or QuickBooks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Synced Prices (Read-Only)")
                }
                
                // Profit margin preview
                if !costText.isEmpty && !sellingPriceText.isEmpty {
                    if let cost = Decimal(string: costText), cost > 0,
                       let price = Decimal(string: sellingPriceText), price > 0 {
                        Section {
                            let margin = ((price - cost) / price) * 100
                            HStack {
                                Text("Profit Margin")
                                Spacer()
                                Text(String(format: "%.1f%%", NSDecimalNumber(decimal: margin).doubleValue))
                                    .bold()
                                    .foregroundColor(margin < 0 ? .red : (margin < 20 ? .orange : .green))
                            }
                        }
                    } else {
                        EmptyView()
                    }
                } else {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePricing()
                    }
                    .bold()
                }
            }
            .onAppear {
                loadInitialValues()
            }
        }
    }
    
    private func loadInitialValues() {
        // Load from cached data (no Core Data access)
        if initialData.cost > 0 {
            costText = String(format: "%.2f", NSDecimalNumber(decimal: initialData.cost).doubleValue)
        }
        
        // Check UserDefaults for manual override
        let manualValue = UserDefaults.standard.double(forKey: "item_selling_price_\(initialData.sku)")
        if manualValue > 0 {
            sellingPriceText = String(format: "%.2f", manualValue)
        } else if let price = initialData.sellingPrice, price > 0 {
            sellingPriceText = String(format: "%.2f", NSDecimalNumber(decimal: price).doubleValue)
        }
    }
    
    private func savePricing() {
        let cost = Decimal(string: costText) ?? 0
        let price = !sellingPriceText.isEmpty ? Decimal(string: sellingPriceText) : nil
        
        onSave(cost, price)
        dismiss()
    }
}

// MARK: - Helper Views

struct ActionButtonContent: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(10)
    }
}


