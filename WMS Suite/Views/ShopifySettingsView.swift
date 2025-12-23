//
//  ShopifySettingsView.swift (UPDATED WITH ORDER SYNC)
//  WMS Suite
//
//  Added order sync functionality
//

import SwiftUI
import CoreData

struct ShopifySettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("shopifyStoreUrl") private var storeUrl = ""
    @AppStorage("shopifyClientId") private var clientId = ""
    
    // For manual token entry (fallback)
    @AppStorage("shopifyAccessToken") private var manualAccessToken = ""
    
    @State private var connectionStatus: String?
    @State private var isTestingConnection = false
    @State private var showingPermissions = false
    @State private var showingOAuthView = false
    @State private var showingInstructions = false
    @State private var useOAuth = false // Default to manual entry (custom apps)
    
    // ✅ NEW: Order sync states
    @State private var isSyncingOrders = false
    @State private var orderSyncStatus: String?
    @State private var showingOrderSyncAlert = false
    
    private var isConnected: Bool {
        ShopifyOAuthManager.shared.hasValidCredentials() || !manualAccessToken.isEmpty
    }
    
    var body: some View {
        Form {
            // Connection Status Section
            if isConnected {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Connected")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text(storeUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                    
                    Button(role: .destructive) {
                        disconnectShopify()
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                } header: {
                    Text("Status")
                }
            }
            
            // OAuth Configuration Section
            Section {
                Toggle("Use OAuth 2.0 (For Public Apps)", isOn: $useOAuth)
                
                if useOAuth {
                    TextField("Store URL", text: $storeUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .disabled(isConnected)
                    
                    TextField("Client ID", text: $clientId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isConnected)
                    
                    if !isConnected {
                        Button(action: { showingOAuthView = true }) {
                            HStack {
                                Image(systemName: "lock.shield")
                                Text("Connect with OAuth")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(storeUrl.isEmpty || clientId.isEmpty)
                    }
                }
            } header: {
                Text("OAuth Authentication")
            } footer: {
                if useOAuth {
                    Text("OAuth is for public apps that need to support multiple stores.")
                } else {
                    Text("Custom apps (like yours) use Admin API access tokens directly. This is the recommended approach for single-store usage.")
                }
            }
            
            // Manual Token Section (Fallback)
            if !useOAuth {
                Section {
                    TextField("Store URL", text: $storeUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    
                    SecureField("Access Token", text: $manualAccessToken)
                        .textContentType(.password)
                } header: {
                    Text("Manual Credentials")
                } footer: {
                    Text("For Shopify custom apps, this is the correct and secure method. Your Admin API access token doesn't expire.")
                }
            }
            
            // ✅ NEW: Sync Actions Section
            Section {
                // Test Connection
                if connectionStatus != nil {
                    Label(connectionStatus!, systemImage: connectionStatus!.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(connectionStatus!.contains("✅") ? .green : .red)
                }
                
                Button(action: testConnection) {
                    if isTestingConnection {
                        HStack {
                            ProgressView()
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Connection", systemImage: "network")
                    }
                }
                .disabled(storeUrl.isEmpty || (!isConnected && !useOAuth && manualAccessToken.isEmpty) || isTestingConnection)
                
                // ✅ NEW: Sync Orders Button
                Button(action: syncOrdersFromShopify) {
                    if isSyncingOrders {
                        HStack {
                            ProgressView()
                            Text("Syncing Orders...")
                        }
                    } else {
                        Label("Sync Orders from Shopify", systemImage: "arrow.down.circle")
                    }
                }
                .disabled(!isConnected || isSyncingOrders)
                
                NavigationLink(destination: ShopifyPermissionsView(
                    storeUrl: storeUrl,
                    accessToken: getCurrentAccessToken()
                )) {
                    Label("Check Permissions", systemImage: "checkmark.shield")
                }
                .disabled(!isConnected)
            } header: {
                Text("Sync & Tools")
            } footer: {
                Text("Sync orders imports last 90 days of Shopify orders into your app")
            }
            
            // Setup Instructions Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Setup Instructions")
                        .font(.headline)
                    
                    if useOAuth {
                        Text("For Public Apps Only")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        SetupStep(number: 1, text: "Create a public app via Shopify Partners")
                        SetupStep(number: 2, text: "Configure Admin API access scopes")
                        SetupStep(number: 3, text: "Copy your Client ID (API key)")
                        SetupStep(number: 4, text: "Enter Store URL and Client ID above")
                        SetupStep(number: 5, text: "Tap 'Connect with OAuth'")
                        SetupStep(number: 6, text: "Authorize the app in your browser")
                    } else {
                        Text("For Custom Apps (Current Setup)")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        SetupStep(number: 1, text: "Your custom app 'wms suite' is already created")
                        SetupStep(number: 2, text: "All required scopes are already configured ✓")
                        SetupStep(number: 3, text: "Go to API credentials tab")
                        SetupStep(number: 4, text: "Copy your Admin API access token")
                        SetupStep(number: 5, text: "Enter Store URL: wms-suite.myshopify.com")
                        SetupStep(number: 6, text: "Paste the access token above")
                        SetupStep(number: 7, text: "Tap 'Test Connection' to verify")
                    }
                    
                    Link(destination: URL(string: "https://admin.shopify.com")!) {
                        HStack {
                            Text("Open Shopify Admin")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 8)
                    
                    Button(action: { showingInstructions = true }) {
                        HStack {
                            Text("View Detailed Guide")
                            Image(systemName: "book")
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 4)
                }
            } header: {
                Text("How to Get Credentials")
            }
        }
        .navigationTitle("Shopify")
        .sheet(isPresented: $showingOAuthView) {
            ShopifyOAuthView(storeUrl: storeUrl) { token in
                connectionStatus = "✅ Connected successfully via OAuth"
                // Token is already stored by ShopifyOAuthManager
            }
        }
        .sheet(isPresented: $showingInstructions) {
            NavigationView {
                ShopifyInstructionsView()
            }
        }
        .alert("Order Sync Complete", isPresented: $showingOrderSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(orderSyncStatus ?? "Orders synced successfully")
        }
    }
    
    private func getCurrentAccessToken() -> String {
        if useOAuth, let token = ShopifyOAuthManager.shared.getAccessToken(for: storeUrl) {
            return token
        }
        return manualAccessToken
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionStatus = nil
        
        Task {
            do {
                let accessToken = getCurrentAccessToken()
                
                guard !accessToken.isEmpty else {
                    throw ShopifyError.missingCredentials
                }
                
                // Try a simple GraphQL query
                let url = URL(string: "https://\(storeUrl)/admin/api/2025-01/graphql.json")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(accessToken, forHTTPHeaderField: "X-Shopify-Access-Token")
                
                let query = """
                {
                    shop {
                        name
                    }
                }
                """
                request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query], options: [])
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ShopifyError.invalidResponse
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    await MainActor.run {
                        connectionStatus = "✅ Connected successfully"
                        isTestingConnection = false
                    }
                } else {
                    throw ShopifyError.httpError(statusCode: httpResponse.statusCode)
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "❌ Connection failed: \(error.localizedDescription)"
                    isTestingConnection = false
                }
            }
        }
    }
    
    // ✅ NEW: Sync orders from Shopify
    private func syncOrdersFromShopify() {
        isSyncingOrders = true
        orderSyncStatus = nil
        
        Task {
            do {
                let shopifyService = ShopifyService()
                
                var syncMessages: [String] = []
                
                try await shopifyService.syncOrders(context: viewContext) { message in
                    syncMessages.append(message)
                    print("📦 \(message)")
                }
                
                await MainActor.run {
                    orderSyncStatus = syncMessages.joined(separator: "\n")
                    isSyncingOrders = false
                    showingOrderSyncAlert = true
                }
            } catch {
                await MainActor.run {
                    orderSyncStatus = "❌ Order sync failed: \(error.localizedDescription)"
                    isSyncingOrders = false
                    showingOrderSyncAlert = true
                }
            }
        }
    }
    
    private func disconnectShopify() {
        ShopifyOAuthManager.shared.revokeAccess()
        storeUrl = ""
        manualAccessToken = ""
        connectionStatus = "Disconnected from Shopify"
    }
}

// MARK: - Setup Step Helper

struct SetupStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Instructions View

struct ShopifyInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Shopify Integration Setup")
                    .font(.title)
                    .bold()
                
                Text("For Custom Apps (Your Current Setup)")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Group {
                    Text("What You Already Have ✓")
                        .font(.headline)
                    Text("• Custom app 'wms suite' created\n• All required API scopes configured\n• Admin API access token generated\n• Ready to connect!")
                        .foregroundColor(.green)
                    
                    Text("How to Connect")
                        .font(.headline)
                    Text("1. Go to your app's 'API credentials' tab\n2. Copy the 'Admin API access token' (ends in eb9c)\n3. In WMS Suite app, go to Settings → Shopify\n4. Enter Store URL: wms-suite.myshopify.com\n5. Paste the access token\n6. Tap 'Test Connection'\n7. Done!")
                    
                    Text("Why Custom Apps Don't Need OAuth")
                        .font(.headline)
                    Text("Custom apps are designed for single-store, private use. They use permanent Admin API tokens that are just as secure as OAuth. OAuth is only needed for public apps that install on multiple stores.")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                
                Divider()
                    .padding(.vertical)
                
                Text("For Public Apps (Future Use)")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Group {
                    Text("If You Build a Public App Later")
                        .font(.headline)
                    Text("Public apps are distributed via the Shopify App Store and can be installed by any store. This requires OAuth.")
                    
                    Text("OAuth Setup Steps")
                        .font(.headline)
                    Text("1. Create app in Shopify Partners (not Shopify Admin)\n2. Configure OAuth redirect URL: wmssuite://shopify/callback\n3. Get Client ID from partner dashboard\n4. In WMS Suite, enable 'Use OAuth 2.0'\n5. Enter Client ID and tap 'Connect with OAuth'\n6. Complete authorization in browser")
                }
                .font(.subheadline)
            }
            .padding()
        }
        .navigationTitle("Setup Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview

struct ShopifySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ShopifySettingsView()
        }
    }
}
