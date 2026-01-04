//
//  TakeOutInventoryView.swift
//  WMS Suite
//
//  Quick interface for taking inventory out (fulfillment, wastage, etc.)
//  Supports: Camera scanning + Bluetooth barcode scanner + Manual entry
//  Search priority: SKU → UPC → WebSKU
//

import SwiftUI
import AVFoundation
import CoreData

struct TakeOutInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: InventoryViewModel
    
    @State private var scanMode: ScanMode = .camera
    @State private var scannedCode = ""
    @State private var manualInput = ""
    @State private var foundItem: InventoryItem?
    @State private var quantityToRemove: String = "1"
    @State private var removalReason: RemovalReason = .fulfillment
    @State private var notes: String = ""
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var takeOutHistory: [TakeOutRecord] = []
    
    // Camera scanner
    @StateObject private var scannerManager = BarcodeScannerManager()
    @FocusState private var isBluetoothFieldFocused: Bool
    @FocusState private var isQuantityFocused: Bool
    
    // Adaptive sizes for iPad
    private var cameraHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 600 : 300
    }
    
    private var scanFrameSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200
    }
    
    enum ScanMode {
        case camera
        case manual
    }
    
    enum RemovalReason: String, CaseIterable, Identifiable {
        case fulfillment = "Order Fulfillment"
        case wastage = "Damaged/Wastage"
        case transfer = "Transfer Out"
        case sample = "Sample/Demo"
        case adjustment = "Inventory Adjustment"
        case other = "Other"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .fulfillment: return "box.truck"
            case .wastage: return "trash"
            case .transfer: return "arrow.right.circle"
            case .sample: return "gift"
            case .adjustment: return "slider.horizontal.3"
            case .other: return "ellipsis.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .fulfillment: return .blue
            case .wastage: return .red
            case .transfer: return .orange
            case .sample: return .purple
            case .adjustment: return .yellow
            case .other: return .gray
            }
        }
    }
    
    struct TakeOutRecord: Identifiable {
        let id = UUID()
        let itemName: String
        let sku: String
        let quantity: Decimal
        let reason: RemovalReason
        let timestamp: Date
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mode Selector
                Picker("Scan Mode", selection: $scanMode) {
                    Text("Camera").tag(ScanMode.camera)
                    Text("Manual").tag(ScanMode.manual)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: scanMode) { oldValue, newValue in
                    resetScanner()
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Scanning Interface
                        switch scanMode {
                        case .camera:
                            cameraScanSection
                        case .manual:
                            manualEntrySection
                        }
                        
                        // Found Item Card
                        if let item = foundItem {
                            foundItemCard(item: item)
                        }
                        
                        // Take Out History
                        if !takeOutHistory.isEmpty {
                            historySection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Take Out Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: scannerManager.scannedCode) { oldValue, newValue in
                if let code = newValue, !code.isEmpty, code != scannedCode {
                    handleScannedCode(code)
                }
            }
            .onChange(of: manualInput) { oldValue, newValue in
                // Debounce to prevent UI lag
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second debounce
                    
                    // Check if input looks like a barcode scan (ends with newline/return)
                    if newValue.contains("\n") || newValue.contains("\r") {
                        let cleanCode = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanCode.isEmpty {
                            handleScannedCode(cleanCode)
                            manualInput = ""
                        }
                    }
                }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    resetForNextScan()
                }
            } message: {
                Text(successMessage)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if scanMode == .camera {
                    Task {
                        scannerManager.startScanning()
                    }
                }
            }
            .onDisappear {
                Task {
                    scannerManager.stopScanning()
                }
            }
        }
    }
    
    // MARK: - Camera Scan Section
    
    private var cameraScanSection: some View {
        VStack(spacing: 16) {
            if scannerManager.isAuthorized {
                ZStack {
                    CameraPreviewView(session: scannerManager.session)
                        .frame(height: cameraHeight)
                        .cornerRadius(12)
                    
                    // Scanning frame overlay - adaptive size
                    Rectangle()
                        .stroke(foundItem == nil ? Color.orange : Color.blue, lineWidth: 4)
                        .frame(width: scanFrameSize, height: scanFrameSize)
                }
                
                if !scannedCode.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Scanned: \(scannedCode)")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                cameraPermissionPrompt
            }
        }
    }
    
    private var cameraPermissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.headline)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Manual Entry Section
    
    private var manualEntrySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Manual Entry")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter Code")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("SKU, UPC, or WebSKU", text: $manualInput)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .onSubmit {
                            handleScannedCode(manualInput)
                        }
                    
                    Button(action: {
                        handleScannedCode(manualInput)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .padding(8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Found Item Card
    
    private func foundItemCard(item: InventoryItem) -> some View {
        VStack(spacing: 16) {
            // Item Info with Stock Warning
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Unknown Item")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if let sku = item.sku {
                            Text("SKU: \(sku)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Convert quantity to Decimal for comparison
                        let currentQty = getQuantityAsDecimal(item.quantity)
                        let minStock = getQuantityAsDecimal(item.minStockLevel)
                        
                        HStack(spacing: 12) {
                            Label("Available: \(formatQuantity(currentQty))", systemImage: "cube.box")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(currentQty > 0 ? .green : .red)
                        }
                        
                        // Low stock warning
                        if currentQty <= minStock && currentQty > 0 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Low Stock Warning")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // Quantity Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Quantity to Remove")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button(action: {
                        if let current = Decimal(string: quantityToRemove), current > 1 {
                            let formatter = NumberFormatter()
                            formatter.minimumFractionDigits = 0
                            formatter.maximumFractionDigits = 2
                            quantityToRemove = formatter.string(from: NSDecimalNumber(decimal: current - 1)) ?? "\(current - 1)"
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Quantity", text: $quantityToRemove)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .frame(width: 100)
                        .focused($isQuantityFocused)
                    
                    Button(action: {
                        if let current = Decimal(string: quantityToRemove) {
                            let formatter = NumberFormatter()
                            formatter.minimumFractionDigits = 0
                            formatter.maximumFractionDigits = 2
                            quantityToRemove = formatter.string(from: NSDecimalNumber(decimal: current + 1)) ?? "\(current + 1)"
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Stock validation warning
                if let qty = Decimal(string: quantityToRemove) {
                    let currentQty = getQuantityAsDecimal(item.quantity)
                    if qty > currentQty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Insufficient stock! Only \(formatQuantity(currentQty)) available")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Removal Reason Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Reason for Removal")
                    .font(.headline)
                
                Picker("Reason", selection: $removalReason) {
                    ForEach(RemovalReason.allCases) { reason in
                        Label(reason.rawValue, systemImage: reason.icon)
                            .tag(reason)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                
                // Show reason color indicator
                HStack {
                    Circle()
                        .fill(removalReason.color)
                        .frame(width: 12, height: 12)
                    Text(removalReason.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Optional Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)")
                    .font(.headline)
                
                TextEditor(text: $notes)
                    .frame(height: 80)
                    .padding(4)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Take Out Button
            Button(action: {
                takeOutItem(item: item)
            }) {
                HStack {
                    Image(systemName: "arrow.up.circle")
                    Text("Remove from Inventory")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidRemoval(item: item) ? Color.red : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isValidRemoval(item: item))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            ForEach(takeOutHistory.prefix(5)) { record in
                HStack {
                    Image(systemName: record.reason.icon)
                        .foregroundColor(record.reason.color)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.itemName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text("SKU: \(record.sku)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(record.reason.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("-\(record.quantity)")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(record.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Validation
    
    private func isValidRemoval(item: InventoryItem) -> Bool {
        guard let quantity = Decimal(string: quantityToRemove) else { return false }
        let currentQty = getQuantityAsDecimal(item.quantity)
        return quantity > 0 && quantity <= currentQty
    }
    
    // MARK: - Actions
    
    private func handleScannedCode(_ code: String) {
        scannedCode = code
        
        // Search priority: SKU → UPC → WebSKU
        let results = viewModel.items.filter { item in
            if let sku = item.sku, sku.lowercased() == code.lowercased() {
                return true
            }
            if let upc = item.upc, upc.lowercased() == code.lowercased() {
                return true
            }
            if let webSKU = item.webSKU, webSKU.lowercased() == code.lowercased() {
                return true
            }
            return false
        }
        
        if let item = results.first {
            foundItem = item
            quantityToRemove = "1"
            
            // Check if item has stock
            let currentQty = getQuantityAsDecimal(item.quantity)
            if currentQty <= 0 {
                errorMessage = "Item '\(item.name ?? "Unknown")' is out of stock"
                showingError = true
            } else {
                // Auto-focus quantity field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isQuantityFocused = true
                }
            }
            
            // Stop scanning if using camera
            if scanMode == .camera {
                scannerManager.stopScanning()
            }
        } else {
            // Item not found
            foundItem = nil
            errorMessage = "Item not found: \(code)"
            showingError = true
        }
    }
    
    private func takeOutItem(item: InventoryItem) {
        guard let quantity = Decimal(string: quantityToRemove), quantity > 0 else {
            errorMessage = "Please enter a valid quantity"
            showingError = true
            return
        }
        
        let currentQty = getQuantityAsDecimal(item.quantity)
        guard quantity <= currentQty else {
            errorMessage = "Cannot remove \(formatQuantity(quantity)) items. Only \(formatQuantity(currentQty)) available."
            showingError = true
            return
        }
        
        // Update inventory
        item.quantity = NSDecimalNumber(decimal: currentQty - quantity)
        item.lastUpdated = Date()
        
        do {
            try viewContext.save()
            
            // Add to history
            let record = TakeOutRecord(
                itemName: item.name ?? "Unknown",
                sku: item.sku ?? "",
                quantity: quantity,
                reason: removalReason,
                timestamp: Date()
            )
            takeOutHistory.insert(record, at: 0)
            
            // Log the transaction (could be expanded to save to database)
            logTransaction(item: item, quantity: quantity, reason: removalReason, notes: notes)
            
            // Show success
            successMessage = "Removed \(quantity) × \(item.name ?? "item") from inventory\nReason: \(removalReason.rawValue)\nRemaining: \(item.quantity)"
            showingSuccess = true
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func logTransaction(item: InventoryItem, quantity: Decimal, reason: RemovalReason, notes: String) {
        // Future enhancement: Save to a transaction log entity
        print("""
        📦 INVENTORY TAKEOUT:
        - Item: \(item.name ?? "Unknown") (\(item.sku ?? "N/A"))
        - Quantity: \(quantity)
        - Reason: \(reason.rawValue)
        - Notes: \(notes.isEmpty ? "None" : notes)
        - New Stock: \(item.quantity)
        - Timestamp: \(Date())
        """)
    }
    
    private func resetForNextScan() {
        foundItem = nil
        scannedCode = ""
        quantityToRemove = "1"
        notes = ""
        
        if scanMode == .camera {
            Task {
                scannerManager.resetScanner()
            }
        }
    }
    
    private func resetScanner() {
        foundItem = nil
        scannedCode = ""
        manualInput = ""
        quantityToRemove = "1"
        notes = ""
        
        if scanMode == .camera {
            Task {
                scannerManager.startScanning()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatQuantity(_ qty: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: qty)) ?? "\(qty)"
    }
    
    // Helper to safely convert quantity to Decimal
    private func getQuantityAsDecimal(_ quantity: Any?) -> Decimal {
        if let decimalNumber = quantity as? NSDecimalNumber {
            return decimalNumber.decimalValue
        } else if let decimal = quantity as? Decimal {
            return decimal
        } else if let int = quantity as? Int32 {
            return Decimal(int)
        } else if let int = quantity as? Int {
            return Decimal(int)
        }
        return 0
    }
}
