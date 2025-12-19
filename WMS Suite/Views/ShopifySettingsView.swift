//
//  ShopifySettingsView.swift (UPDATED)
//  WMS Suite
//
//  Updated to include permissions checker
//

import SwiftUI

struct ShopifySettingsView: View {
    @AppStorage("shopifyStoreUrl") private var storeUrl = ""
    @AppStorage("shopifyAccessToken") private var accessToken = ""
    
    @State private var connectionStatus: String?
    @State private var isTestingConnection = false
    @State private var showingPermissions = false
    
    var body: some View {
        Form {
            Section {
                TextField("Store URL", text: $storeUrl)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                
                SecureField("Access Token", text: $accessToken)
                    .textContentType(.password)
            } header: {
                Text("Credentials")
            } footer: {
                Text("Enter your-store.myshopify.com (without https://)")
            }
            
            Section {
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
                .disabled(storeUrl.isEmpty || accessToken.isEmpty || isTestingConnection)
                
                NavigationLink(destination: ShopifyPermissionsView(storeUrl: storeUrl, accessToken: accessToken)) {
                    Label("Check Permissions", systemImage: "checkmark.shield")
                }
                .disabled(storeUrl.isEmpty || accessToken.isEmpty)
            } header: {
                Text("Connection")
            } footer: {
                Text("Check which API permissions are enabled for your access token")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Setup Instructions")
                        .font(.headline)
                    
                    Text("1. Go to your Shopify Admin")
                        .font(.caption)
                    Text("2. Apps → Develop apps → Create an app")
                        .font(.caption)
                    Text("3. Configure Admin API scopes:")
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("   • read_products")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("   • write_products")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("   • read_inventory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("   • write_inventory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("   • read_orders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("4. Install app and copy Access Token")
                        .font(.caption)
                    Text("5. Enter credentials above")
                        .font(.caption)
                    Text("6. Tap 'Check Permissions' to verify setup")
                        .font(.caption)
                    
                    Link(destination: URL(string: "https://admin.shopify.com")!) {
                        HStack {
                            Text("Open Shopify Admin")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
            } header: {
                Text("How to Get Credentials")
            }
        }
        .navigationTitle("Shopify")
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionStatus = nil
        
        Task {
            do {
                let service = ShopifyService(storeUrl: storeUrl, accessToken: accessToken)
                
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
}
