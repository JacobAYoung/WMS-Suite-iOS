//
//  ShopifyPermissionsView.swift
//  WMS Suite
//
//  Shows which Shopify permissions are enabled/disabled
//

import SwiftUI

struct ShopifyPermissionsView: View {
    let storeUrl: String
    let accessToken: String
    
    @State private var permissions: [ShopifyPermission] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Checking permissions...")
                            .foregroundColor(.secondary)
                    }
                }
            } else if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
            } else {
                Section {
                    ForEach(permissions) { permission in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(permission.name)
                                    .font(.headline)
                                Text(permission.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: permission.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(permission.isEnabled ? .green : .red)
                                .font(.title2)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("API Permissions")
                } footer: {
                    if permissions.contains(where: { !$0.isEnabled }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚠️ Some permissions are disabled")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            
                            Text("To enable missing permissions:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("1. Go to your Shopify Admin")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("2. Apps → Develop apps → Your app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("3. Configuration → Admin API scopes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("4. Enable the required scopes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("5. Reinstall the app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    } else {
                        Text("✅ All required permissions are enabled")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await checkPermissions()
                        }
                    }) {
                        Label("Re-check Permissions", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationTitle("Shopify Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkPermissions()
        }
    }
    
    private func checkPermissions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let checker = ShopifyPermissionsChecker(storeUrl: storeUrl, accessToken: accessToken)
            permissions = try await checker.checkPermissions()
            
            // Store permission states for later use
            UserDefaults.standard.set(hasPermission("write_inventory"), forKey: "shopify_canWriteInventory")
            UserDefaults.standard.set(hasPermission("read_products"), forKey: "shopify_canReadProducts")
            
        } catch {
            errorMessage = "Failed to check permissions: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func hasPermission(_ scope: String) -> Bool {
        permissions.first(where: { $0.scope == scope })?.isEnabled ?? false
    }
}

struct ShopifyPermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ShopifyPermissionsView(
                storeUrl: "your-store.myshopify.com",
                accessToken: "test-token"
            )
        }
    }
}
