//
//  SettingsView.swift
//  WMS Suite
//
//  UPDATED: Added QuickBooks integration section
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @AppStorage("shopifyStoreUrl") private var shopifyStoreUrl = ""
    @AppStorage("shopifyAccessToken") private var shopifyAccessToken = ""
    @AppStorage("enableAutoSync") private var enableAutoSync = false
    @AppStorage("syncInterval") private var syncInterval = 60
    @State private var showingClearDataAlert = false
    @State private var showingConnectionTest = false
    @State private var connectionTestResult = ""
    @State private var connectionTestSuccess = false
    @State private var isTestingConnection = false
    
    var body: some View {
        NavigationView {
            Form {
                // SECTION: Integrations
                Section("Integrations") {
                    // Shopify
                    NavigationLink(destination: ShopifySettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "cart.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Shopify")
                                    .font(.headline)
                                Text(shopifyStoreUrl.isEmpty ? "Not configured" : shopifyStoreUrl)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // QuickBooks (NEW!)
                    NavigationLink(destination: QuickBooksSettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("QuickBooks")
                                    .font(.headline)
                                Text(qbConnectionStatus)
                                    .font(.caption)
                                    .foregroundColor(qbConnectionStatusColor)
                            }
                        }
                    }
                }
                .headerProminence(.increased)
                
                Section("Data Management") {
                    Button(action: exportData) {
                        Label("Export Data (CSV)", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: importData) {
                        Label("Import Data (CSV)", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(role: .destructive, action: { showingClearDataAlert = true }) {
                        Label("Clear All Data", systemImage: "trash")
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
                
                Section("About") {
                    Link(destination: URL(string: "https://harbordesksystems.com")!) {
                        Label("Website", systemImage: "globe")
                    }
                    
                    Link(destination: URL(string: "https://github.com/JacobAYoung/WMS-Suite-iOS")!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                    
                    Link(destination: URL(string: "https://harbordesksystems.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://harbordesksystems.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
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
            .alert("Connection Test", isPresented: $showingConnectionTest) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(connectionTestResult)
            }
        }
    }
    
    // MARK: - QuickBooks Status Helper
    
    private var qbConnectionStatus: String {
        let tokenManager = QuickBooksTokenManager.shared
        if tokenManager.isAuthenticated {
            if let companyId = tokenManager.getCompanyId() {
                return "Connected - \(companyId)"
            }
            return "Connected"
        } else {
            return "Not connected"
        }
    }
    
    private var qbConnectionStatusColor: Color {
        QuickBooksTokenManager.shared.isAuthenticated ? .green : .secondary
    }
    
    // MARK: - Shopify Connection Test
    
    private func testShopifyConnection() {
        guard !shopifyStoreUrl.isEmpty && !shopifyAccessToken.isEmpty else {
            connectionTestResult = "Please enter both Store URL and Access Token"
            connectionTestSuccess = false
            showingConnectionTest = true
            return
        }
        
        isTestingConnection = true
        
        Task {
            do {
                let url = URL(string: "https://\(shopifyStoreUrl)/admin/api/2025-01/graphql.json")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(shopifyAccessToken, forHTTPHeaderField: "X-Shopify-Access-Token")
                
                let query = """
                {
                    shop {
                        name
                        email
                    }
                }
                """
                
                request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query], options: [])
                
                let (data, response) = try await NetworkService.performRequest(request: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        connectionTestResult = "Invalid response from server"
                        connectionTestSuccess = false
                        showingConnectionTest = true
                        isTestingConnection = false
                    }
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataDict = json["data"] as? [String: Any],
                       let shop = dataDict["shop"] as? [String: Any],
                       let shopName = shop["name"] as? String {
                        await MainActor.run {
                            connectionTestResult = "✓ Successfully connected to: \(shopName)"
                            connectionTestSuccess = true
                            showingConnectionTest = true
                            isTestingConnection = false
                        }
                    } else {
                        await MainActor.run {
                            connectionTestResult = "✓ Connection successful!"
                            connectionTestSuccess = true
                            showingConnectionTest = true
                            isTestingConnection = false
                        }
                    }
                } else if httpResponse.statusCode == 401 {
                    await MainActor.run {
                        connectionTestResult = "✗ Authentication failed. Please check your Access Token."
                        connectionTestSuccess = false
                        showingConnectionTest = true
                        isTestingConnection = false
                    }
                } else if httpResponse.statusCode == 404 {
                    await MainActor.run {
                        connectionTestResult = "✗ Store not found. Please check your Store URL."
                        connectionTestSuccess = false
                        showingConnectionTest = true
                        isTestingConnection = false
                    }
                } else {
                    await MainActor.run {
                        connectionTestResult = "✗ Connection failed with status code: \(httpResponse.statusCode)"
                        connectionTestSuccess = false
                        showingConnectionTest = true
                        isTestingConnection = false
                    }
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = "✗ Connection failed: \(error.localizedDescription)"
                    connectionTestSuccess = false
                    showingConnectionTest = true
                    isTestingConnection = false
                }
            }
        }
    }
    
    // MARK: - Data Management
    
    private func exportData() {
        let csvString = generateCSV()
        shareCSV(csvString)
    }
    
    private func generateCSV() -> String {
        var csv = "SKU,Name,Description,UPC,Quantity,MinStockLevel,LastUpdated\n"
        
        for item in viewModel.items {
            let sku = item.sku ?? ""
            let name = item.name ?? ""
            let desc = item.itemDescription ?? ""
            let upc = item.upc ?? ""
            let qty = "\(item.quantity)"
            let minStock = "\(item.minStockLevel)"
            let updated = item.lastUpdated?.ISO8601Format() ?? ""
            
            csv += "\(sku),\(name),\(desc),\(upc),\(qty),\(minStock),\(updated)\n"
        }
        
        return csv
    }
    
    private func shareCSV(_ csvString: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("inventory_export.csv")
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Error exporting CSV: \(error)")
        }
    }
    
    private func importData() {
        print("Importing data...")
    }
    
    private func clearAllData() {
        for item in viewModel.items {
            viewModel.deleteItem(item)
        }
    }
}

#Preview {
    SettingsView(viewModel: InventoryViewModel(
        repository: InventoryRepository(context: PersistenceController.preview.container.viewContext),
        shopifyService: ShopifyService(storeUrl: "", accessToken: ""),
        quickbooksService: QuickBooksService(companyId: "", accessToken: "", refreshToken: ""),
        barcodeService: BarcodeService()
    ))
}
