//
//  QuickBooksInvoiceSyncView.swift
//  WMS Suite
//
//  UI for syncing invoices from QuickBooks with progress tracking
//

import SwiftUI
import CoreData

struct QuickBooksInvoiceSyncView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var tokenManager = QuickBooksTokenManager.shared
    
    @State private var isSyncing = false
    @State private var syncProgress: String = ""
    @State private var syncLogs: [String] = []
    @State private var showResults = false
    
    @State private var syncResult: SyncResult?
    
    struct SyncResult {
        let totalFetched: Int
        let created: Int
        let updated: Int
        let errors: Int
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status
                    connectionStatusCard
                    
                    // Sync Button
                    if tokenManager.isAuthenticated {
                        syncButtonSection
                    }
                    
                    // Progress Section
                    if isSyncing {
                        syncProgressSection
                    }
                    
                    // Results Section
                    if let result = syncResult {
                        syncResultsSection(result: result)
                    }
                    
                    // Sync Logs
                    if !syncLogs.isEmpty {
                        syncLogsSection
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("QuickBooks Invoice Sync")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: tokenManager.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(tokenManager.isAuthenticated ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tokenManager.isAuthenticated ? "Connected to QuickBooks" : "Not Connected")
                        .font(.headline)
                    
                    if tokenManager.isAuthenticated {
                        if let companyId = tokenManager.getCompanyId() {
                            Text("Company ID: \(companyId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Please connect in Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if !tokenManager.isAuthenticated {
                Button(action: {
                    // Open Settings
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Go to Settings")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Sync Button Section
    
    private var syncButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await startInvoiceSync()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                    Text("Sync Invoices from QuickBooks")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSyncing ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isSyncing)
            
            Text("This will import all invoices from QuickBooks Online")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Sync Progress Section
    
    private var syncProgressSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text(syncProgress)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Please wait, this may take a few moments...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Sync Results Section
    
    private func syncResultsSection(result: SyncResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Sync Complete")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                resultStatCard(
                    title: "Total Fetched",
                    value: "\(result.totalFetched)",
                    icon: "cloud.fill",
                    color: .blue
                )
                
                resultStatCard(
                    title: "New Invoices",
                    value: "\(result.created)",
                    icon: "plus.circle.fill",
                    color: .green
                )
                
                resultStatCard(
                    title: "Updated",
                    value: "\(result.updated)",
                    icon: "arrow.clockwise.circle.fill",
                    color: .orange
                )
                
                resultStatCard(
                    title: "Errors",
                    value: "\(result.errors)",
                    icon: "exclamationmark.triangle.fill",
                    color: result.errors > 0 ? .red : .gray
                )
            }
            
            Button(action: {
                syncResult = nil
                syncLogs = []
            }) {
                Text("Dismiss")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func resultStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Sync Logs Section
    
    private var syncLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.blue)
                Text("Sync Log")
                    .font(.headline)
                Spacer()
                
                Button(action: {
                    syncLogs = []
                }) {
                    Text("Clear")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(syncLogs.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(syncLogs[index])
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Sync Logic
    
    private func startInvoiceSync() async {
        guard let accessToken = tokenManager.getCurrentAccessToken(),
              let companyId = tokenManager.getCompanyId() else {
            await MainActor.run {
                addLog("❌ Missing authentication tokens")
            }
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncProgress = "Initializing sync..."
            syncLogs = []
            syncResult = nil
        }
        
        let service = QuickBooksService(
            companyId: companyId,
            accessToken: accessToken,
            refreshToken: tokenManager.getCurrentRefreshToken() ?? ""
        )
        
        do {
            // Track stats
            var totalFetched = 0
            var created = 0
            var updated = 0
            var errors = 0
            
            // Perform sync with logging callback
            try await service.syncInvoices(context: viewContext) { message in
                Task { @MainActor in
                    addLog(message)
                    syncProgress = message
                    
                    // Parse results from messages
                    if message.contains("Fetched") {
                        if let count = extractNumber(from: message) {
                            totalFetched = count
                        }
                    } else if message.contains("Created") {
                        if let count = extractNumber(from: message, searchTerm: "Created") {
                            created = count
                        }
                    } else if message.contains("updated") {
                        if let count = extractNumber(from: message, searchTerm: "updated") {
                            updated = count
                        }
                    }
                }
            }
            
            await MainActor.run {
                isSyncing = false
                syncProgress = "Sync completed successfully"
                
                syncResult = SyncResult(
                    totalFetched: totalFetched,
                    created: created,
                    updated: updated,
                    errors: errors
                )
                
                addLog("✅ Invoice sync completed successfully!")
            }
            
        } catch {
            await MainActor.run {
                isSyncing = false
                syncProgress = "Sync failed"
                addLog("❌ Error: \(error.localizedDescription)")
                
                syncResult = SyncResult(
                    totalFetched: 0,
                    created: 0,
                    updated: 0,
                    errors: 1
                )
            }
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        syncLogs.append("[\(timestamp)] \(message)")
    }
    
    private func extractNumber(from text: String, searchTerm: String = "") -> Int? {
        let pattern = searchTerm.isEmpty ? #"\d+"# : #"\b(\d+)\b"#
        
        if let range = text.range(of: pattern, options: .regularExpression) {
            let numberString = String(text[range])
            return Int(numberString)
        }
        return nil
    }
}

// MARK: - Preview

struct QuickBooksInvoiceSyncView_Previews: PreviewProvider {
    static var previews: some View {
        QuickBooksInvoiceSyncView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
