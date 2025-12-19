//
//  QuickBooksSettingsView.swift (UPDATED)
//  WMS Suite
//
//  Updated to include Client ID/Secret for auto token refresh
//

import SwiftUI

struct QuickBooksSettingsView: View {
    @AppStorage("quickbooksCompanyId") private var companyId = ""
    @AppStorage("quickbooksAccessToken") private var accessToken = ""
    @AppStorage("quickbooksRefreshToken") private var refreshToken = ""
    @AppStorage("quickbooksClientId") private var clientId = ""
    @AppStorage("quickbooksClientSecret") private var clientSecret = ""
    
    @AppStorage("quickbooksIncomeAccountId") private var incomeAccountId = ""
    @AppStorage("quickbooksCOGSAccountId") private var cogsAccountId = ""
    @AppStorage("quickbooksAssetAccountId") private var assetAccountId = ""
    
    @State private var showingAccountSetup = false
    @State private var connectionStatus: String?
    @State private var isTestingConnection = false
    @State private var showingInstructions = false
    
    var body: some View {
        Form {
            Section {
                TextField("Company ID (Realm ID)", text: $companyId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                SecureField("Access Token", text: $accessToken)
                    .textContentType(.password)
                
                SecureField("Refresh Token", text: $refreshToken)
                    .textContentType(.password)
            } header: {
                Text("OAuth Credentials")
            } footer: {
                Text("Access tokens expire hourly but will refresh automatically if you provide Client ID and Secret below.")
            }
            
            Section {
                TextField("Client ID", text: $clientId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                SecureField("Client Secret", text: $clientSecret)
                    .textContentType(.password)
            } header: {
                Text("App Credentials (For Auto Token Refresh)")
            } footer: {
                Text("Optional: Get these from your Intuit Developer app. When provided, access tokens will refresh automatically.")
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
                .disabled(companyId.isEmpty || accessToken.isEmpty || isTestingConnection)
                
                Button(action: { showingAccountSetup = true }) {
                    Label("Configure Accounts", systemImage: "list.bullet.rectangle")
                }
                .disabled(companyId.isEmpty || accessToken.isEmpty)
            } header: {
                Text("Connection")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Setup Instructions")
                        .font(.headline)
                    
                    SetupStep(number: 1, text: "Go to developer.intuit.com")
                    SetupStep(number: 2, text: "Create an app (or use existing)")
                    SetupStep(number: 3, text: "Copy Client ID and Client Secret from 'Keys & Credentials' (optional, for auto-refresh)")
                    SetupStep(number: 4, text: "Use OAuth Playground to get tokens")
                    SetupStep(number: 5, text: "Select scope: 'com.intuit.quickbooks.accounting'")
                    SetupStep(number: 6, text: "Enter Company ID, Access Token, and Refresh Token above")
                    SetupStep(number: 7, text: "Optionally enter Client ID/Secret for automatic token refresh")
                    SetupStep(number: 8, text: "Tap 'Configure Accounts' to set up income, COGS, and asset accounts")
                    
                    Link(destination: URL(string: "https://developer.intuit.com")!) {
                        HStack {
                            Text("Open Developer Portal")
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
        .navigationTitle("QuickBooks Online")
        .sheet(isPresented: $showingAccountSetup) {
            AccountSetupView(
                companyId: companyId,
                accessToken: accessToken
            )
        }
        .sheet(isPresented: $showingInstructions) {
            NavigationView {
                QuickBooksInstructionsView()
            }
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionStatus = nil
        
        Task {
            do {
                let service = QuickBooksService(
                    companyId: companyId,
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
                
                // Try to fetch accounts as a connection test
                _ = try await service.fetchAccounts()
                
                await MainActor.run {
                    connectionStatus = "✅ Connected successfully"
                    isTestingConnection = false
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

struct QuickBooksInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("QuickBooks Online Setup Guide")
                    .font(.title)
                    .bold()
                
                Group {
                    Text("Step 1: Create Developer App")
                        .font(.headline)
                    Text("1. Go to developer.intuit.com\n2. Sign in with your Intuit account\n3. Click 'My Apps' → 'Create an app'\n4. Choose 'QuickBooks Online and Payments'\n5. Name your app (e.g., 'WMS Suite')")
                    
                    Text("Step 2: Get Client Credentials (Optional)")
                        .font(.headline)
                    Text("1. In your app dashboard, go to 'Keys & OAuth'\n2. Copy your Client ID\n3. Copy your Client Secret\n4. These enable automatic token refresh (recommended)")
                    
                    Text("Step 3: Get OAuth Tokens")
                        .font(.headline)
                    Text("1. Go to developer.intuit.com/app/developer/playground\n2. Select your app\n3. Select scopes: 'Accounting'\n4. Click 'Get authorization code'\n5. Log in to QuickBooks and authorize\n6. Copy the Realm ID (Company ID)\n7. Copy the Access Token\n8. Copy the Refresh Token")
                    
                    Text("Step 4: Configure in WMS Suite")
                        .font(.headline)
                    Text("1. Enter all credentials in Settings\n2. Tap 'Test Connection'\n3. Tap 'Configure Accounts'\n4. Select your Income, COGS, and Asset accounts\n5. Done!")
                    
                    Text("Token Expiration")
                        .font(.headline)
                    Text("• Access tokens expire after 1 hour\n• If you provided Client ID/Secret: Tokens refresh automatically ✅\n• If not: You'll need to manually refresh tokens from OAuth Playground")
                }
                .font(.subheadline)
            }
            .padding()
        }
        .navigationTitle("Instructions")
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
