//
//  QuickBooksAutoSyncManager.swift
//  WMS Suite
//
//  Manages automatic background syncing with QuickBooks
//  Syncs customers and invoices on app launch, foreground, and periodic intervals
//

import Foundation
import CoreData
import UIKit

@MainActor
class QuickBooksAutoSyncManager: ObservableObject {
    static let shared = QuickBooksAutoSyncManager()
    
    // MARK: - Published Properties
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var lastSyncStatus: SyncStatus = .idle
    
    // MARK: - Sync Status
    
    enum SyncStatus {
        case idle
        case syncing
        case success(customersCount: Int, invoicesCount: Int, inventoryCount: Int)
        case failure(error: String)
        
        var description: String {
            switch self {
            case .idle:
                return "Ready to sync"
            case .syncing:
                return "Syncing..."
            case .success(let customers, let invoices, let inventory):
                return "Synced \(customers) customers, \(invoices) invoices, \(inventory) items"
            case .failure(let error):
                return "Sync failed: \(error)"
            }
        }
    }
    
    // MARK: - Configuration
    
    private let syncInterval: TimeInterval = 4 * 3600 // 4 hours
    private let staleDataThreshold: TimeInterval = 24 * 3600 // 24 hours
    
    // Enable/disable auto sync (persisted)
    var isAutoSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "quickbooksAutoSyncEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "quickbooksAutoSyncEnabled")
            if newValue {
                scheduleNextSync()
            } else {
                Task { @MainActor in
                    cancelScheduledSync()
                }
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var syncTimer: Timer?
    private var isSyncInProgress = false
    
    // MARK: - Initialization
    
    private init() {
        // Load last sync date
        if let lastSync = UserDefaults.standard.object(forKey: "quickbooksLastSyncDate") as? Date {
            self.lastSyncDate = lastSync
        }
        
        // Auto-enable sync on first launch
        if !UserDefaults.standard.bool(forKey: "quickbooksAutoSyncConfigured") {
            isAutoSyncEnabled = true
            UserDefaults.standard.set(true, forKey: "quickbooksAutoSyncConfigured")
        }
        
        print("📱 QuickBooks Auto Sync Manager initialized")
        print("   Auto sync enabled: \(isAutoSyncEnabled)")
        if let lastSync = lastSyncDate {
            print("   Last sync: \(lastSync.formatted())")
        }
        
        // Setup app lifecycle observers
        setupLifecycleObservers()
    }
    
    // MARK: - Lifecycle Observers
    
    private func setupLifecycleObservers() {
        // Sync when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppBecameActive()
            }
        }
        
        // Cancel timer when app goes to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillResignActive()
        }
        
        print("✅ App lifecycle observers registered")
    }
    
    // MARK: - App Lifecycle Handlers
    
    private func handleAppBecameActive() async {
        guard isAutoSyncEnabled else { return }
        
        print("📱 App became active, checking if sync needed...")
        
        // Check if we should sync
        if shouldSyncNow() {
            print("✅ Auto-sync triggered (app became active)")
            await syncIfNeeded()
        } else {
            print("ℹ️ Data is fresh, skipping auto-sync")
        }
        
        // Schedule periodic sync
        scheduleNextSync()
    }
    
    private func handleAppWillResignActive() {
        print("📱 App will resign active, cancelling scheduled sync")
        Task { @MainActor in
            cancelScheduledSync()
        }
    }
    
    // MARK: - Sync Logic
    
    /// Check if we should sync based on last sync time
    func shouldSyncNow() -> Bool {
        guard QuickBooksTokenManager.shared.isAuthenticated else {
            return false
        }
        
        guard let lastSync = lastSyncDate else {
            return true // Never synced
        }
        
        let timeSinceLastSync = Date().timeIntervalSince(lastSync)
        return timeSinceLastSync >= staleDataThreshold
    }
    
    /// Perform sync if needed (checks staleness and auth status)
    func syncIfNeeded() async {
        guard isAutoSyncEnabled else {
            print("ℹ️ Auto-sync disabled, skipping")
            return
        }
        
        guard QuickBooksTokenManager.shared.isAuthenticated else {
            print("ℹ️ Not authenticated, skipping auto-sync")
            return
        }
        
        guard !isSyncInProgress else {
            print("ℹ️ Sync already in progress, skipping")
            return
        }
        
        guard shouldSyncNow() else {
            print("ℹ️ Data is fresh, skipping sync")
            return
        }
        
        await performSync()
    }
    
    /// Force sync regardless of staleness
    func forceSync() async {
        guard QuickBooksTokenManager.shared.isAuthenticated else {
            print("❌ Cannot sync: Not authenticated")
            lastSyncStatus = .failure(error: "Not connected to QuickBooks")
            return
        }
        
        await performSync()
    }
    
    /// Perform the actual sync operation
    private func performSync() async {
        guard !isSyncInProgress else {
            print("⚠️ Sync already in progress")
            return
        }
        
        isSyncInProgress = true
        isSyncing = true
        lastSyncStatus = .syncing
        
        print("🔄 Starting automatic QuickBooks sync...")
        
        do {
            // Get the Core Data context
            guard let context = PersistenceController.shared.container.viewContext as NSManagedObjectContext? else {
                throw NSError(domain: "QuickBooksAutoSync", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not access Core Data context"
                ])
            }
            
            // Create QuickBooks service
            guard let accessToken = QuickBooksTokenManager.shared.getCurrentAccessToken(),
                  let companyId = QuickBooksTokenManager.shared.getCompanyId() else {
                throw NSError(domain: "QuickBooksAutoSync", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Missing access token or company ID"
                ])
            }
            
            let refreshToken = QuickBooksTokenManager.shared.getCurrentRefreshToken() ?? ""
            let useSandbox = QuickBooksTokenManager.shared.useSandbox
            
            let service = QuickBooksService(
                companyId: companyId,
                accessToken: accessToken,
                refreshToken: refreshToken,
                useSandbox: useSandbox
            )
            
            var customersCount = 0
            var invoicesCount = 0
            var inventoryCount = 0
            
            // Sync customers
            print("📇 Syncing customers...")
            try await service.syncCustomers(context: context) { message in
                print("   \(message)")
            }
            
            // Count customers synced
            let customerFetch = NSFetchRequest<Customer>(entityName: "Customer")
            customerFetch.predicate = NSPredicate(format: "quickbooksCustomerId != nil")
            customersCount = try context.count(for: customerFetch)
            
            // Sync invoices
            print("🧾 Syncing invoices...")
            try await service.syncInvoices(context: context) { message in
                print("   \(message)")
            }
            
            // Count invoices synced
            let invoiceFetch = NSFetchRequest<Sale>(entityName: "Sale")
            invoiceFetch.predicate = NSPredicate(format: "source == %@", "quickbooks")
            invoicesCount = try context.count(for: invoiceFetch)
            
            // Sync inventory items
            print("📦 Syncing inventory...")
            try await service.syncInventory(context: context) { message in
                print("   \(message)")
            }
            
            // Count inventory synced
            let inventoryFetch = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
            inventoryFetch.predicate = NSPredicate(format: "quickbooksItemId != nil")
            inventoryCount = try context.count(for: inventoryFetch)
            
            // Update sync status
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "quickbooksLastSyncDate")
            
            lastSyncStatus = .success(customersCount: customersCount, invoicesCount: invoicesCount, inventoryCount: inventoryCount)
            
            print("✅ Auto-sync completed successfully")
            print("   Customers: \(customersCount)")
            print("   Invoices: \(invoicesCount)")
            print("   Inventory: \(inventoryCount)")
            
        } catch {
            print("❌ Auto-sync failed: \(error.localizedDescription)")
            lastSyncStatus = .failure(error: error.localizedDescription)
        }
        
        isSyncInProgress = false
        isSyncing = false
    }
    
    // MARK: - Periodic Sync Scheduling
    
    /// Schedule the next periodic sync
    private func scheduleNextSync() {
        // Cancel any existing timer
        cancelScheduledSync()
        
        guard isAutoSyncEnabled else { return }
        guard QuickBooksTokenManager.shared.isAuthenticated else { return }
        
        print("⏰ Scheduling next auto-sync in \(syncInterval / 3600) hours")
        
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: syncInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.syncIfNeeded()
            }
        }
    }
    
    /// Cancel scheduled periodic sync
    @MainActor
    private func cancelScheduledSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Start auto-sync (enable and trigger initial sync)
    func start() {
        isAutoSyncEnabled = true
        Task {
            await syncIfNeeded()
        }
    }
    
    /// Stop auto-sync (disable and cancel timers)
    func stop() {
        isAutoSyncEnabled = false
        Task { @MainActor in
            cancelScheduledSync()
        }
    }
    
    /// Get time since last sync (formatted)
    func timeSinceLastSync() -> String? {
        guard let lastSync = lastSyncDate else {
            return nil
        }
        
        let interval = Date().timeIntervalSince(lastSync)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    /// Check if data is stale
    var isDataStale: Bool {
        shouldSyncNow()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { @MainActor in
            cancelScheduledSync()
        }
    }
}
