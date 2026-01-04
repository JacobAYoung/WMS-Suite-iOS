//
//  PutAwayInventoryView.swift
//  WMS Suite
//
//  Quick interface for receiving and putting away inventory
//  Supports: Camera scanning + Bluetooth barcode scanner + Manual entry
//  Search priority: SKU → UPC → WebSKU
//

import SwiftUI
import AVFoundation
import CoreData

struct PutAwayInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: InventoryViewModel
    
    @State private var scanMode: ScanMode = .camera
    @State private var scannedCode = ""
    @State private var manualInput = ""
    @State private var foundItem: InventoryItem?
    @State private var quantityToAdd: String = "1"
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var putAwayHistory: [PutAwayRecord] = []
    
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
    
    struct PutAwayRecord: Identifiable {
        let id = UUID()
        let itemName: String
        let sku: String
        let quantity: Decimal
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
                        
                        // Put Away History
                        if !putAwayHistory.isEmpty {
                            historySection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Put Away Inventory")
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
                // Debounce to prevent UI lag - Bluetooth scanners work as keyboard input
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
                        .stroke(foundItem == nil ? Color.green : Color.blue, lineWidth: 4)
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
    
    // MARK: - Bluetooth Scanner Section removed (redundant - scanner works as keyboard)
    
    // MARK: - Manual Entry Section
    
    private var manualEntrySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
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
                            .background(Color.blue)
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
            // Item Info
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
                        
                        HStack(spacing: 12) {
                            Label("Current: \(item.quantity)", systemImage: "cube.box")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Quantity Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Quantity to Add")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button(action: {
                        if let current = Decimal(string: quantityToAdd), current > 1 {
                            let formatter = NumberFormatter()
                            formatter.minimumFractionDigits = 0
                            formatter.maximumFractionDigits = 2
                            quantityToAdd = formatter.string(from: NSDecimalNumber(decimal: current - 1)) ?? "\(current - 1)"
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Quantity", text: $quantityToAdd)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .frame(width: 100)
                        .focused($isQuantityFocused)
                    
                    Button(action: {
                        if let current = Decimal(string: quantityToAdd) {
                            let formatter = NumberFormatter()
                            formatter.minimumFractionDigits = 0
                            formatter.maximumFractionDigits = 2
                            quantityToAdd = formatter.string(from: NSDecimalNumber(decimal: current + 1)) ?? "\(current + 1)"
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Put Away Button
            Button(action: {
                putAwayItem(item: item)
            }) {
                HStack {
                    Image(systemName: "arrow.down.to.line.compact")
                    Text("Put Away")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(quantityToAdd.isEmpty || Decimal(string: quantityToAdd) == nil || Decimal(string: quantityToAdd)! <= 0)
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
            
            ForEach(putAwayHistory.prefix(5)) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.itemName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("SKU: \(record.sku)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("+\(record.quantity)")
                            .font(.headline)
                            .foregroundColor(.green)
                        
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
            quantityToAdd = "1"
            
            // Auto-focus quantity field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isQuantityFocused = true
            }
            
            // Stop scanning if using camera
            if scanMode == .camera {
                scannerManager.stopScanning()
            }
        } else {
            // Item not found
            foundItem = nil
            successMessage = "Item not found: \(code)"
            showingSuccess = true
        }
    }
    
    private func putAwayItem(item: InventoryItem) {
        guard let quantity = Decimal(string: quantityToAdd), quantity > 0 else { return }
        
        // Update inventory
        let currentQty = (item.quantity as? NSDecimalNumber)?.decimalValue ?? 0
        item.quantity = NSDecimalNumber(decimal: currentQty + quantity)
        item.lastUpdated = Date()
        
        do {
            try viewContext.save()
            
            // Add to history
            let record = PutAwayRecord(
                itemName: item.name ?? "Unknown",
                sku: item.sku ?? "",
                quantity: quantity,
                timestamp: Date()
            )
            putAwayHistory.insert(record, at: 0)
            
            // Show success
            successMessage = "Added \(quantity) × \(item.name ?? "item") to inventory\nNew total: \(item.quantity)"
            showingSuccess = true
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } catch {
            successMessage = "Error: \(error.localizedDescription)"
            showingSuccess = true
        }
    }
    
    private func resetForNextScan() {
        foundItem = nil
        scannedCode = ""
        quantityToAdd = "1"
        
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
        quantityToAdd = "1"
        
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
}
