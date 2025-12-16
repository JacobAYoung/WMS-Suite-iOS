//
//  QuickBooksSettingsView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import SwiftUI

struct QuickBooksSettingsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @AppStorage("quickbooksCompanyId") private var quickbooksCompanyId = ""
    @AppStorage("quickbooksAccessToken") private var quickbooksAccessToken = ""
    
    @State private var showingConnectionTest = false
    @State private var connectionTestResult = ""
    @State private var isTestingConnection = false
    
    var body: some View {
        Form {
            Section {
                TextField("Company ID", text: $quickbooksCompanyId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                SecureField("Access Token", text: $quickbooksAccessToken)
                    .textContentType(.password)
            } header: {
                Text("QuickBooks Online Credentials")
            } footer: {
                Text("Enter your QuickBooks Online Company ID and OAuth access token.")
            }
            
            Section {
                Button(action: testQuickBooksConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text(isTestingConnection ? "Testing..." : "Test Connection")
                        Spacer()
                    }
                }
                .disabled(quickbooksCompanyId.isEmpty || quickbooksAccessToken.isEmpty || isTestingConnection)
            } header: {
                Text("QuickBooks Online Connection")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("QuickBooks Online Integration")
                        .font(.headline)
                    Text("This app supports QuickBooks Online. To get your credentials:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Go to developer.intuit.com")
                        Text("2. Create an app")
                        Text("3. Get your Company ID and access token")
                        Text("4. Grant appropriate permissions")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } header: {
                Text("Setup Instructions")
            } footer: {
                Text("For QuickBooks Desktop: Use IIF export in Data Management.")
            }
        }
        .navigationTitle("QuickBooks")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Connection Test", isPresented: $showingConnectionTest) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionTestResult)
        }
    }
    
    private func testQuickBooksConnection() {
        guard !quickbooksCompanyId.isEmpty && !quickbooksAccessToken.isEmpty else {
            connectionTestResult = "Please enter both Company ID and Access Token"
            showingConnectionTest = true
            return
        }
        
        isTestingConnection = true
        
        // TODO: Implement actual QuickBooks connection test
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                connectionTestResult = "⚠️ QuickBooks Online API integration is not yet implemented. For QuickBooks Desktop, use the IIF export in Data Management."
                showingConnectionTest = true
                isTestingConnection = false
            }
        }
    }
}
