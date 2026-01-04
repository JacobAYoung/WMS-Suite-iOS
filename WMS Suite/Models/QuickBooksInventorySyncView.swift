//
//  QuickBooksInventorySyncView.swift
//  WMS Suite
//
//  View for manually syncing inventory items from QuickBooks
//

import SwiftUI
import CoreData

struct QuickBooksInventorySyncView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tokenManager = QuickBooksTokenManager.shared
    
    @State private var isSyncing = false
    @State private var syncCompleted = false
    @State private var errorMessage: String?
    @State private var syncLogs: [String] = []
    @State private var inventoryItems: [InventoryItem] = []
    @State private var stats: SyncStats?
    
    struct SyncStats {
        var totalItems: Int
        var newItems: Int
        var updatedItems: Int
        var syncDuration: TimeInterval
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if syncCompleted {
                    completedView
                } else if isSyncing {
                    syncingView
                } else {
                    readyView
                }
            }
            .navigationTitle("Sync Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isSyncing)
                }
            }
        }
    }
    
    // MARK: - Ready View
    
    private var readyView: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .padding(.top, 40)
            
            // Title
            Text("Sync Inventory from QuickBooks")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "arrow.down.circle.fill", text: "Import all inventory items from QuickBooks")
                FeatureRow(icon: "tag.fill", text: "Sync SKUs, names, and descriptions")
                FeatureRow(icon: "number.circle.fill", text: "Update quantities and stock levels")
                FeatureRow(icon: "dollarsign.circle.fill", text: "Import costs and selling prices")
                FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Match existing items by QuickBooks ID")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Warning
            if !inventoryItems.isEmpty {
                Text("\(inventoryItems.count) items currently synced")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Sync Button
            Button(action: startSync) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Start Sync")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .onAppear {
            loadExistingItems()
        }
    }
    
    // MARK: - Syncing View
    
    private var syncingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated icon
            ProgressView()
                .scaleEffect(2)
                .padding(.bottom, 24)
            
            Text("Syncing Inventory...")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This may take a minute")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Logs
            if !syncLogs.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(syncLogs, id: \.self) { log in
                            HStack(alignment: .top, spacing: 8) {
                                if log.contains("✅") {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if log.contains("❌") {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                } else if log.contains("📄") {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(log)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Completed View
    
    private var completedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if let error = errorMessage {
                // Error state
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Sync Failed")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
            } else if let stats = stats {
                // Success state
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Sync Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Stats
                VStack(spacing: 16) {
                    StatRow(label: "Total Items", value: "\(stats.totalItems)")
                    StatRow(label: "New Items", value: "\(stats.newItems)", color: .green)
                    StatRow(label: "Updated Items", value: "\(stats.updatedItems)", color: .blue)
                    StatRow(label: "Duration", value: String(format: "%.1fs", stats.syncDuration))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Done Button
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Actions
    
    private func loadExistingItems() {
        Task {
            let items = await Task.detached {
                let context = PersistenceController.shared.container.viewContext
                return await context.perform {
                    let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
                    fetchRequest.predicate = NSPredicate(format: "quickbooksItemId != nil")
                    return (try? context.fetch(fetchRequest)) ?? []
                }
            }.value
            
            await MainActor.run {
                inventoryItems = items
            }
        }
    }
    
    private func startSync() {
        isSyncing = true
        syncLogs = []
        errorMessage = nil
        
        let startTime = Date()
        
        Task {
            do {
                // Get credentials
                guard let accessToken = tokenManager.getCurrentAccessToken(),
                      let companyId = tokenManager.getCompanyId() else {
                    throw NSError(domain: "QuickBooksSync", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Not connected to QuickBooks"
                    ])
                }
                
                let refreshToken = tokenManager.getCurrentRefreshToken() ?? ""
                let useSandbox = tokenManager.useSandbox
                
                // Create service
                let service = QuickBooksService(
                    companyId: companyId,
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    useSandbox: useSandbox
                )
                
                // Sync inventory
                await addLog("Starting inventory sync...")
                
                try await service.syncInventory(context: viewContext) { message in
                    Task { @MainActor in
                        await self.addLog(message)
                    }
                }
                
                // Get updated counts
                let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
                fetchRequest.predicate = NSPredicate(format: "quickbooksItemId != nil")
                let allItems = try viewContext.fetch(fetchRequest)
                
                let duration = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    let newCount = allItems.count - inventoryItems.count
                    let updatedCount = min(inventoryItems.count, allItems.count)
                    
                    stats = SyncStats(
                        totalItems: allItems.count,
                        newItems: max(0, newCount),
                        updatedItems: updatedCount,
                        syncDuration: duration
                    )
                    
                    isSyncing = false
                    syncCompleted = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSyncing = false
                    syncCompleted = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    @MainActor
    private func addLog(_ message: String) async {
        syncLogs.append(message)
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#Preview {
    QuickBooksInventorySyncView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
