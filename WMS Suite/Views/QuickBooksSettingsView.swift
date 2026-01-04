//
//  QuickBooksSettingsView.swift
//  WMS Suite
//
//  ✅ CLEANED UP VERSION - Removed credential input, simplified UI
//  Users just click "Connect" - OAuth credentials are hard-coded in app
//

import SwiftUI
import CoreData

struct QuickBooksSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var tokenManager = QuickBooksTokenManager.shared
    @StateObject private var autoSyncManager = QuickBooksAutoSyncManager.shared
    
    // UI State
    @State private var isConnecting = false
    @State private var isDisconnecting = false
    @State private var isClearingData = false
    @State private var errorMessage: String?
    @State private var errorRecoverySuggestion: String?
    @State private var showingHelp = false
    @State private var showingClearDataAlert = false
    @State private var showingSuccessAlert = false
    @State private var successMessage: String?
    
    // Sync views
    @State private var showingCustomerSync = false
    @State private var showingInvoiceSync = false
    @State private var showingInventorySync = false
    
    var body: some View {
        Form {
            // Connection Status
            connectionStatusSection
            
            // Quick Actions
            quickActionsSection
            
            // Data Sync (only when connected)
            if tokenManager.isAuthenticated {
                dataSyncSection
                autoSyncSection
            }
            
            // Environment Toggle
            environmentSection
            
            // Help & Instructions
            helpSection
        }
        .navigationTitle("QuickBooks")
        .navigationBarTitleDisplayMode(.large)
        .loading(
            isConnecting || isDisconnecting || isClearingData || autoSyncManager.isSyncing,
            message: loadingMessage
        )
        .alert("Connection Error", isPresented: .constant(errorMessage != nil && !showingSuccessAlert)) {
            Button("OK", role: .cancel) {
                errorMessage = nil
                errorRecoverySuggestion = nil
            }
            if errorRecoverySuggestion != nil {
                Button("Retry") {
                    errorMessage = nil
                    errorRecoverySuggestion = nil
                    connect()
                }
            }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                if let error = errorMessage {
                    Text(error)
                }
                if let suggestion = errorRecoverySuggestion {
                    Text("\n\(suggestion)")
                        .font(.caption)
                }
            }
        }
        .alert("Success!", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) {
                successMessage = nil
            }
        } message: {
            if let message = successMessage {
                Text(message)
            }
        }
        .sheet(isPresented: $showingHelp) {
            NavigationView {
                QuickBooksHelpView()
            }
        }
        .sheet(isPresented: $showingCustomerSync) {
            QuickBooksCustomerSyncView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingInvoiceSync) {
            QuickBooksInvoiceSyncView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingInventorySync) {
            QuickBooksInventorySyncView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // MARK: - Connection Status Section
    
    private var connectionStatusSection: some View {
        Section {
            HStack(spacing: 16) {
                // Status Icon
                Image(systemName: tokenManager.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(tokenManager.isAuthenticated ? .green : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tokenManager.isAuthenticated ? "Connected" : "Not Connected")
                        .font(.headline)
                    
                    if let companyId = tokenManager.getCompanyId() {
                        Text("Company ID: \(companyId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Tap Connect to link your QuickBooks account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show token expiry if connected
                    if tokenManager.isAuthenticated, let expiry = tokenManager.getTokenExpiryDate() {
                        let timeUntilExpiry = expiry.timeIntervalSinceNow
                        if timeUntilExpiry > 0 {
                            Text("Token expires: \(formatTimeInterval(timeUntilExpiry))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        Section {
            if tokenManager.isAuthenticated {
                // Disconnect Button
                Button(role: .destructive, action: disconnect) {
                    HStack {
                        if isDisconnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Disconnecting...")
                        } else {
                            Label("Disconnect QuickBooks", systemImage: "power")
                        }
                    }
                }
                .disabled(isDisconnecting)
            } else {
                // Connect Button
                Button(action: connect) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "link.circle.fill")
                        }
                        Text(isConnecting ? "Connecting..." : "Connect to QuickBooks")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)
                .listRowBackground(Color.accentColor.opacity(0.1))
            }
        }
    }
    
    // MARK: - Data Sync Section
    
    private var dataSyncSection: some View {
        Section {
            // Sync Customers
            Button(action: { showingCustomerSync = true }) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync Customers")
                            .font(.body)
                        Text("Import customers from QuickBooks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sync Invoices
            Button(action: { showingInvoiceSync = true }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.green)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync Invoices")
                            .font(.body)
                        Text("Import invoices from QuickBooks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sync Inventory
            Button(action: { showingInventorySync = true }) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync Inventory")
                            .font(.body)
                        Text("Import inventory items from QuickBooks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Clear QuickBooks Data (Destructive)
            Button(role: .destructive, action: { showingClearDataAlert = true }) {
                HStack {
                    if isClearingData {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 30)
                    } else {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 30)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isClearingData ? "Clearing..." : "Clear QuickBooks Data")
                            .font(.body)
                        if !isClearingData {
                            Text("Delete all synced customers, invoices & inventory")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .disabled(isClearingData)
        } header: {
            Text("Data Sync")
        } footer: {
            Text("Sync your QuickBooks data into the app. Customers must be synced before invoices to link them properly.")
        }
        .alert("Clear QuickBooks Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear QB Data", role: .destructive) {
                clearQuickBooksData()
            }
        } message: {
            Text("This will delete all customers, invoices, and inventory items synced from QuickBooks.\n\n✅ Local data will NOT be deleted.\n\nYou can re-sync anytime.")
        }
    }
    
    // MARK: - Auto Sync Section
    
    private var autoSyncSection: some View {
        Section {
            // Auto-sync toggle
            Toggle(isOn: Binding(
                get: { autoSyncManager.isAutoSyncEnabled },
                set: { newValue in
                    autoSyncManager.isAutoSyncEnabled = newValue
                    if newValue {
                        Task {
                            await autoSyncManager.syncIfNeeded()
                        }
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic Sync")
                        .font(.body)
                    Text("Sync data automatically in background")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Last sync status
            if let lastSync = autoSyncManager.lastSyncDate {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Sync")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let timeAgo = autoSyncManager.timeSinceLastSync() {
                            Text(timeAgo)
                                .font(.body)
                        }
                    }
                    
                    Spacer()
                    
                    // Sync status indicator
                    syncStatusIndicator
                }
            } else if autoSyncManager.isAutoSyncEnabled {
                HStack {
                    Text("Never synced")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Sync Now") {
                        Task {
                            await autoSyncManager.forceSync()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            
            // Manual sync button
            if autoSyncManager.isAutoSyncEnabled {
                Button(action: {
                    Task {
                        await autoSyncManager.forceSync()
                    }
                }) {
                    HStack {
                        if autoSyncManager.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Now")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(autoSyncManager.isSyncing)
            }
            
        } header: {
            Text("Automatic Sync")
        } footer: {
            if autoSyncManager.isAutoSyncEnabled {
                if autoSyncManager.isDataStale {
                    Text("⚠️ Data is stale (> 24 hours old). Sync recommended.")
                } else {
                    Text("Data syncs automatically every 4 hours and when app opens. Last sync: \(autoSyncManager.lastSyncStatus.description)")
                }
            } else {
                Text("Enable to keep QuickBooks data up-to-date automatically.")
            }
        }
    }
    
    // Sync status indicator
    private var syncStatusIndicator: some View {
        Group {
            switch autoSyncManager.lastSyncStatus {
            case .idle:
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            case .syncing:
                ProgressView()
                    .scaleEffect(0.8)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Environment Section
    
    private var environmentSection: some View {
        Section {
            Toggle(isOn: $tokenManager.useSandbox) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sandbox Mode")
                        .font(.body)
                    Text("Use test environment for development")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(tokenManager.isAuthenticated) // Can't change while connected
        } header: {
            Text("Environment")
        } footer: {
            if tokenManager.isAuthenticated {
                Text("Disconnect to change environment settings.")
            } else {
                Text("Enable Sandbox to test with fake data. Disable for production use with real QuickBooks company.")
            }
        }
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        Section {
            Button(action: { showingHelp = true }) {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                    Text("How QuickBooks Integration Works")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://developer.intuit.com/app/developer/qbo/docs/get-started")!) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text("API Documentation")
                }
            }
        } header: {
            Text("Help & Resources")
        }
    }
    
    // MARK: - Actions
    
    private func connect() {
        isConnecting = true
        errorMessage = nil
        errorRecoverySuggestion = nil
        
        print("🔗 User tapped Connect to QuickBooks")
        
        // Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to present login screen. Please restart the app."
            isConnecting = false
            return
        }
        
        // Start OAuth flow with completion handler
        tokenManager.startOAuthFlow(presentingViewController: rootViewController) { [self] result in
            DispatchQueue.main.async {
                self.isConnecting = false
                
                switch result {
                case .success:
                    // Show success message
                    self.successMessage = "Successfully connected to QuickBooks!\n\nYou can now sync your customers and invoices."
                    self.showingSuccessAlert = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    print("✅ Connection successful!")
                    
                    // Trigger initial auto-sync
                    if autoSyncManager.isAutoSyncEnabled {
                        Task {
                            await autoSyncManager.syncIfNeeded()
                        }
                    }
                    
                case .failure(let error):
                    // Don't show error if user cancelled
                    if case .userCancelled = error {
                        print("ℹ️ User cancelled - no error shown")
                        return
                    }
                    
                    // Show user-friendly error message
                    self.errorMessage = error.localizedDescription
                    self.errorRecoverySuggestion = error.recoverySuggestion
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    
                    print("❌ Connection failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func disconnect() {
        isDisconnecting = true
        
        Task {
            // Add small delay for visual feedback
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            await MainActor.run {
                tokenManager.logout()
                errorMessage = nil
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
                
                isDisconnecting = false
            }
        }
    }
    
    private func clearQuickBooksData() {
        isClearingData = true
        
        Task {
            var customerCount = 0
            var invoiceCount = 0
            var inventoryCount = 0
            var errorOccurred = false
            var errorDetails = ""
            
            // Perform on background context
            await Task.detached(priority: .userInitiated) {
                let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
                
                await backgroundContext.perform {
                    do {
                        print("🗑️ Clearing QuickBooks data...")
                        
                        // Delete all QuickBooks customers (keeps local customers safe)
                        let customerFetch = NSFetchRequest<Customer>(entityName: "Customer")
                        customerFetch.predicate = NSPredicate(format: "quickbooksCustomerId != nil")
                        
                        let qbCustomers = try backgroundContext.fetch(customerFetch)
                        customerCount = qbCustomers.count
                        print("   Deleting \(customerCount) QuickBooks customers...")
                        qbCustomers.forEach { backgroundContext.delete($0) }
                        
                        // Delete all QuickBooks invoices (keeps local orders safe)
                        let salesFetch = NSFetchRequest<Sale>(entityName: "Sale")
                        salesFetch.predicate = NSPredicate(format: "source == %@", "quickbooks")
                        
                        let qbInvoices = try backgroundContext.fetch(salesFetch)
                        invoiceCount = qbInvoices.count
                        print("   Deleting \(invoiceCount) QuickBooks invoices...")
                        qbInvoices.forEach { backgroundContext.delete($0) }
                        
                        // Delete all QuickBooks inventory items (keeps local items safe)
                        let inventoryFetch = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
                        inventoryFetch.predicate = NSPredicate(format: "quickbooksItemId != nil")
                        
                        let qbInventory = try backgroundContext.fetch(inventoryFetch)
                        inventoryCount = qbInventory.count
                        print("   Deleting \(inventoryCount) QuickBooks inventory items...")
                        qbInventory.forEach { backgroundContext.delete($0) }
                        
                        // Save changes
                        try backgroundContext.save()
                        print("✅ QuickBooks data cleared successfully")
                        
                    } catch {
                        print("❌ Error clearing QB data: \(error)")
                        errorOccurred = true
                        errorDetails = error.localizedDescription
                    }
                }
            }.value
            
            // Update UI on main thread
            await MainActor.run {
                isClearingData = false
                
                if errorOccurred {
                    errorMessage = "Failed to clear QuickBooks data"
                    errorRecoverySuggestion = errorDetails
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                } else {
                    // Show success message
                    successMessage = """
                    Successfully deleted:
                    • \(customerCount) QuickBooks customer\(customerCount == 1 ? "" : "s")
                    • \(invoiceCount) invoice\(invoiceCount == 1 ? "" : "s")
                    • \(inventoryCount) inventory item\(inventoryCount == 1 ? "" : "s")
                    
                    Your local data is safe.
                    """
                    showingSuccessAlert = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var loadingMessage: String {
        if isConnecting {
            return "Connecting to QuickBooks..."
        } else if isDisconnecting {
            return "Disconnecting..."
        } else if isClearingData {
            return "Clearing QuickBooks Data..."
        } else if autoSyncManager.isSyncing {
            return "Syncing Data..."
        }
        return "Loading..."
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 24 {
            let days = hours / 24
            return "in \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}

// MARK: - Help View

struct QuickBooksHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🎯 How It Works")
                        .font(.title2)
                        .bold()
                    
                    Text("QuickBooks integration is already configured. Just tap Connect!")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("What Happens When You Connect") {
                InstructionStep(
                    number: 1,
                    title: "Tap 'Connect to QuickBooks'",
                    detail: "The QuickBooks login page will open"
                )
                InstructionStep(
                    number: 2,
                    title: "Sign In",
                    detail: "Login with your QuickBooks Online account"
                )
                InstructionStep(
                    number: 3,
                    title: "Authorize",
                    detail: "Grant WMS Suite access to your data"
                )
                InstructionStep(
                    number: 4,
                    title: "Sync Data",
                    detail: "Import customers and invoices"
                )
            }
            
            Section("What Data Is Synced") {
                Label("Customers with contact information", systemImage: "person.2.fill")
                    .font(.caption)
                Label("Invoices with line items", systemImage: "doc.text.fill")
                    .font(.caption)
                Label("Inventory items with pricing & quantities", systemImage: "shippingbox.fill")
                    .font(.caption)
            }
            
            Section("Important Notes") {
                Label("Use Sandbox mode for testing", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                Label("Switch to Production for live data", systemImage: "checkmark.circle")
                    .font(.caption)
                Label("Tokens refresh automatically", systemImage: "arrow.clockwise")
                    .font(.caption)
                Label("You can disconnect anytime", systemImage: "power")
                    .font(.caption)
            }
        }
        .navigationTitle("QuickBooks Help")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        QuickBooksSettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
