//
//  AccountSetupView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
//

import SwiftUI

struct AccountSetupView: View {
    let companyId: String
    let accessToken: String
    
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("quickbooksIncomeAccountId") private var incomeAccountId = ""
    @AppStorage("quickbooksCOGSAccountId") private var cogsAccountId = ""
    @AppStorage("quickbooksAssetAccountId") private var assetAccountId = ""
    
    @State private var accounts: [QBAccount] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var incomeAccounts: [QBAccount] {
        accounts.filter { $0.accountType == "Income" || $0.accountType == "Other Income" }
    }
    
    var cogsAccounts: [QBAccount] {
        accounts.filter { $0.accountType == "Cost of Goods Sold" }
    }
    
    var assetAccounts: [QBAccount] {
        accounts.filter { $0.accountType == "Other Current Asset" }
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Loading accounts...")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                    
                    Section {
                        Button("Retry") {
                            Task {
                                await loadAccounts()
                            }
                        }
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Income Account")
                                .font(.headline)
                            Text("Where product sales revenue is recorded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Income Account", selection: $incomeAccountId) {
                                Text("Select Account").tag("")
                                ForEach(incomeAccounts) { account in
                                    Text(account.name).tag(account.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("COGS Account")
                                .font(.headline)
                            Text("Cost of Goods Sold - expense account for inventory costs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("COGS Account", selection: $cogsAccountId) {
                                Text("Select Account").tag("")
                                ForEach(cogsAccounts) { account in
                                    Text(account.name).tag(account.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Asset Account")
                                .font(.headline)
                            Text("Inventory asset account - tracks inventory value")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Asset Account", selection: $assetAccountId) {
                                Text("Select Account").tag("")
                                ForEach(assetAccounts) { account in
                                    Text(account.name).tag(account.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why These Accounts?")
                                .font(.headline)
                            
                            Text("QuickBooks requires three account references for inventory items:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text("•")
                                    Text("Income: Where sales revenue is recorded")
                                }
                                HStack(alignment: .top) {
                                    Text("•")
                                    Text("COGS: Cost of goods sold expense")
                                }
                                HStack(alignment: .top) {
                                    Text("•")
                                    Text("Asset: Current inventory value")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    if !incomeAccountId.isEmpty && !cogsAccountId.isEmpty && !assetAccountId.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("All accounts configured!")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Configure Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(incomeAccountId.isEmpty || cogsAccountId.isEmpty || assetAccountId.isEmpty)
                }
            }
            .task {
                await loadAccounts()
            }
        }
    }
    
    private func loadAccounts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let service = QuickBooksService(
                companyId: companyId,
                accessToken: accessToken,
                refreshToken: UserDefaults.standard.string(forKey: "quickbooksRefreshToken") ?? ""
            )
            
            accounts = try await service.fetchAccounts()
            
            if accounts.isEmpty {
                errorMessage = "No accounts found. Please create accounts in QuickBooks first."
            }
            
        } catch {
            errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct AccountSetupView_Previews: PreviewProvider {
    static var previews: some View {
        AccountSetupView(
            companyId: "123456",
            accessToken: "test-token"
        )
    }
}
