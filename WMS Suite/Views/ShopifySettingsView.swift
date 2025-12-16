//
//  ShopifySettingsView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import SwiftUI

struct ShopifySettingsView: View {
    @AppStorage("shopifyStoreUrl") private var shopifyStoreUrl = ""
    @AppStorage("shopifyAccessToken") private var shopifyAccessToken = ""
    @AppStorage("enableAutoSync") private var enableAutoSync = false
    @AppStorage("syncInterval") private var syncInterval = 60
    
    @State private var showingConnectionTest = false
    @State private var connectionTestResult = ""
    @State private var connectionTestSuccess = false
    @State private var isTestingConnection = false
    
    var body: some View {
        Form {
            Section {
                TextField("Store URL", text: $shopifyStoreUrl)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                
                SecureField("Access Token", text: $shopifyAccessToken)
                    .textContentType(.password)
            } header: {
                Text("Credentials")
            } footer: {
                Text("Enter your Shopify store URL (e.g., mystore.myshopify.com) and Admin API access token.")
            }
            
            Section {
                Toggle("Auto Sync", isOn: $enableAutoSync)
                
                if enableAutoSync {
                    Picker("Sync Interval", selection: $syncInterval) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                        Text("4 hours").tag(240)
                    }
                }
            } header: {
                Text("Sync Settings")
            }
            
            Section {
                Button(action: testShopifyConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text(isTestingConnection ? "Testing..." : "Test Connection")
                        Spacer()
                    }
                }
                .disabled(shopifyStoreUrl.isEmpty || shopifyAccessToken.isEmpty || isTestingConnection)
            } header: {
                Text("Connection")
            }
        }
        .navigationTitle("Shopify")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Connection Test", isPresented: $showingConnectionTest) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionTestResult)
        }
    }
    
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
                // Try REST API first (simpler than GraphQL)
                let url = URL(string: "https://\(shopifyStoreUrl)/admin/api/2025-01/shop.json")!
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue(shopifyAccessToken, forHTTPHeaderField: "X-Shopify-Access-Token")
                request.timeoutInterval = 30
                
                print("Testing connection to: \(url)")
                
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
                
                print("Response status code: \(httpResponse.statusCode)")
                
                if (200...299).contains(httpResponse.statusCode) {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let shop = json["shop"] as? [String: Any],
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
                print("Connection test error: \(error)")
                await MainActor.run {
                    connectionTestResult = "✗ Connection failed: \(error.localizedDescription)"
                    connectionTestSuccess = false
                    showingConnectionTest = true
                    isTestingConnection = false
                }
            }
        }
    }
}
