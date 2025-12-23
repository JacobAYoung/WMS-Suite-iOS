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
    
    // MARK: - Computed Properties
    
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
                productInfoSection
                actionButtonsSection
                forecastSection
                salesHistorySection
            }
            .padding(.vertical)
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshTrigger)  // ✅ NEW: Force view to rebuild when this changes
        .onAppear {
            loadSalesHistory()
            loadQuickForecast()
        }
        // ✅ UPDATED: Refresh when returning from sheets
        .onChange(of: showingAddSale) { isShowing in
            if !isShowing {
                // Sheet was dismissed, refresh data
                loadSalesHistory()
                loadQuickForecast()
                // Force ViewModel to reload items list
                viewModel.fetchItems()
            }
        }
        .onChange(of: showingEditItem) { isShowing in
            if !isShowing {
                // ✅ CRITICAL: Force complete refresh when edit sheet closes
                print("🔄 EditItemView closed, refreshing data...")
                loadSalesHistory()
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
            
            if item.minStockLevel > 0 {
                InfoRow(label: "Min Stock Level", value: "\(item.minStockLevel)")
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
                ForEach(salesHistory.prefix(3)) { sale in
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
                                Text("Order: \(orderNum)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                
                if salesHistory.count > 3 {
                    Text("Showing 3 of \(salesHistory.count) sales")
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
    
    // MARK: - Helper Methods
    
    private func loadSalesHistory() {
        let sales = Sale.fetchSales(for: item, context: viewContext)
        
        salesHistory = sales.compactMap { sale in
            guard let lineItems = sale.lineItems as? Set<SaleLineItem>,
                  let lineItem = lineItems.first(where: { $0.item == item }) else {
                return nil
            }
            
            return SalesHistoryDisplay(
                saleDate: sale.saleDate,
                orderNumber: sale.orderNumber,
                quantity: lineItem.quantity
            )
        }
    }
    
    private func loadQuickForecast() {
        Task {
            quickForecast = await viewModel.calculateForecast(for: item, days: 30)
        }
    }
    
    private func pushToService(_ service: ItemSource) {
        Task {
            do {
                switch service {
                case .shopify:
                    try await viewModel.pushToShopify(item: item)
                case .quickbooks:
                    try await viewModel.pushToQuickBooks(item: item)
                case .local:
                    break
                }
            } catch {
                print("Error pushing to \(service.rawValue): \(error)")
            }
        }
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
