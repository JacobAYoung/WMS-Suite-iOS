//
//  QuickScanView.swift
//  WMS Suite
//
//  Quick scanner for viewing product details
//  Supports: Camera scanning + Bluetooth barcode scanner (keyboard wedge)
//  Search priority: SKU → UPC → WebSKU
//

import SwiftUI
import AVFoundation

struct QuickScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: InventoryViewModel
    
    @State private var scanMode: ScanMode = .camera
    @State private var manualInput = ""
    @State private var searchResults: [InventoryItem] = []
    @State private var selectedItem: InventoryItem?
    @State private var showingDetail = false
    @State private var lastScannedCode = ""
    
    // Camera scanner
    @StateObject private var scannerManager = BarcodeScannerManager()
    
    // Adaptive scan frame size for iPad
    private var scanFrameSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 450 : 250
    }
    
    enum ScanMode {
        case camera
        case bluetooth
        case manual
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mode Selector
                Picker("Scan Mode", selection: $scanMode) {
                    Text("Camera").tag(ScanMode.camera)
                    Text("Bluetooth").tag(ScanMode.bluetooth)
                    Text("Manual").tag(ScanMode.manual)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on mode
                switch scanMode {
                case .camera:
                    cameraView
                case .bluetooth:
                    bluetoothView
                case .manual:
                    manualView
                }
                
                // Results Section
                if !searchResults.isEmpty {
                    resultsSection
                }
            }
            .navigationTitle("Quick Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: scannerManager.scannedCode) { oldValue, newValue in
                if let code = newValue, !code.isEmpty, code != lastScannedCode {
                    lastScannedCode = code
                    searchForItem(code: code)
                }
            }
            .onChange(of: manualInput) { oldValue, newValue in
                if !newValue.isEmpty {
                    // Search as they type (with slight delay handled by debounce)
                    searchForItem(code: newValue)
                }
            }
            .sheet(item: $selectedItem) { item in
                ProductDetailView(viewModel: viewModel, item: item)
            }
        }
    }
    
    // MARK: - Camera View
    
    private var cameraView: some View {
        ZStack {
            if scannerManager.isAuthorized {
                CameraPreviewView(session: scannerManager.session)
                    .edgesIgnoringSafeArea(.bottom)
                
                // Scanning overlay
                VStack {
                    Spacer()
                    
                    // Scanning frame - adaptive size for iPad
                    Rectangle()
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: scanFrameSize, height: scanFrameSize)
                    
                    Spacer()
                    
                    if !lastScannedCode.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Scanned: \(lastScannedCode)")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                            Button(action: {
                                scannerManager.resetScanner()
                                lastScannedCode = ""
                                searchResults = []
                            }) {
                                Text("Scan Next")
                                    .font(.subheadline)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.bottom, 20)
                    } else {
                        Text("Align barcode within the frame")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(.bottom, 20)
                    }
                }
            } else {
                cameraPermissionView
            }
        }
        .onAppear {
            if scanMode == .camera {
                scannerManager.startScanning()
            }
        }
        .onDisappear {
            scannerManager.stopScanning()
        }
    }
    
    private var cameraPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.title2)
            
            Text("Please enable camera access in Settings to scan barcodes")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                Text("Open Settings")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    // MARK: - Bluetooth Scanner View
    
    private var bluetoothView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "barcode")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Bluetooth Scanner Ready")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Scan a barcode with your Bluetooth scanner")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Hidden text field that captures bluetooth scanner input
            TextField("", text: $manualInput)
                .textFieldStyle(.roundedBorder)
                .opacity(0.01) // Nearly invisible but can still receive focus
                .frame(width: 1, height: 1)
                .focused($isBluetoothFieldFocused)
            
            if !lastScannedCode.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Scanned: \(lastScannedCode)")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    
                    Button(action: {
                        manualInput = ""
                        lastScannedCode = ""
                        searchResults = []
                        isBluetoothFieldFocused = true
                    }) {
                        Text("Scan Next")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Make sure your Bluetooth scanner is connected and configured as a keyboard device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            // Auto-focus the hidden text field
            isBluetoothFieldFocused = true
        }
    }
    
    @FocusState private var isBluetoothFieldFocused: Bool
    
    // MARK: - Manual Entry View
    
    private var manualView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "keyboard")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("Manual Entry")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Type or paste a SKU, UPC, or WebSKU")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter Code")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("SKU, UPC, or WebSKU", text: $manualInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit {
                        if !manualInput.isEmpty {
                            searchForItem(code: manualInput)
                        }
                    }
                
                if !manualInput.isEmpty {
                    Button(action: {
                        manualInput = ""
                        searchResults = []
                        lastScannedCode = ""
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            HStack {
                Text("Results (\(searchResults.count))")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(searchResults) { item in
                        Button(action: {
                            selectedItem = item
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "Unknown Item")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 12) {
                                        if let sku = item.sku {
                                            Label(sku, systemImage: "number")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Label("\(item.quantity)", systemImage: "cube.box")
                                            .font(.caption)
                                            .foregroundColor(item.quantity > 0 ? .green : .red)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Search Logic
    
    private func searchForItem(code: String) {
        // Search priority: SKU → UPC → WebSKU
        searchResults = viewModel.items.filter { item in
            // First check SKU (highest priority)
            if let sku = item.sku, sku.lowercased() == code.lowercased() {
                return true
            }
            // Then check UPC
            if let upc = item.upc, upc.lowercased() == code.lowercased() {
                return true
            }
            // Finally check WebSKU
            if let webSKU = item.webSKU, webSKU.lowercased() == code.lowercased() {
                return true
            }
            return false
        }
        
        // If exactly one result, auto-open it after a brief delay
        if searchResults.count == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                selectedItem = searchResults.first
            }
        }
    }
}

// MARK: - Scanner Reset Helper

// Note: BarcodeScannerManager.hasScanned and methods are accessed directly in the view
// No extension needed - the class properties are already accessible
