//
//  BarcodeScannerView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import SwiftUI
import AVFoundation
import Vision

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: InventoryViewModel
    @StateObject private var scannerManager = BarcodeScannerManager()
    @State private var searchResults: [InventoryItem] = []
    @State private var showingResults = false
    @State private var scannedCode = ""
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview
                if scannerManager.isAuthorized {
                    CameraPreviewView(session: scannerManager.session)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("Camera Access Required")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Please enable camera access in Settings to scan barcodes")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))
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
                }
                
                // Scanning overlay
                VStack {
                    // Top bar showing what was scanned
                    if !scannedCode.isEmpty {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.green)
                            Text("Scanned: \(scannedCode)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Scanning frame
                    Rectangle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 250, height: 250)
                    
                    Spacer()
                    
                    // Instructions
                    Text("Align barcode within the frame")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                print("Scanner view appeared")
                print("Authorization status: \(scannerManager.isAuthorized)")
                scannerManager.startScanning()
            }
            .onDisappear {
                print("Scanner view disappeared")
                scannerManager.stopScanning()
            }
            .onChange(of: scannerManager.scannedCode) { _, newValue in
                if let code = newValue, !code.isEmpty {
                    print("Code scanned: \(code)")
                    scannedCode = code
                    searchForItem(code: code)
                }
            }
            .sheet(isPresented: $showingResults) {
                SearchResultsView(
                    scannedCode: scannedCode,
                    results: searchResults,
                    viewModel: viewModel,
                    isPresented: $showingResults
                )
            }
        }
    }
    
    private func searchForItem(code: String) {
        // Search priority: UPC → SKU → webSKU
        searchResults = viewModel.items.filter { item in
            return item.upc == code ||
                   item.sku == code ||
                   item.webSKU == code
        }
        
        showingResults = true
    }
}

// MARK: - Barcode Scanner Manager
class BarcodeScannerManager: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isAuthorized = false
    
    let session = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    func checkAuthorization() {
        print("Checking camera authorization...")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera already authorized")
            isAuthorized = true
            setupCaptureSession()
        case .notDetermined:
            print("Requesting camera authorization...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    print("Camera authorization granted: \(granted)")
                    self.isAuthorized = granted
                    if granted {
                        self.setupCaptureSession()
                    }
                }
            }
        default:
            print("Camera not authorized")
            isAuthorized = false
        }
    }
    
    private func setupCaptureSession() {
        print("Setting up capture session...")
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Failed to get video capture device")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Failed to create video input: \(error)")
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            print("Video input added")
        } else {
            print("Could not add video input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .code128, .code39, .code93, .upce
            ]
            print("Metadata output configured")
        } else {
            print("Could not add metadata output")
            return
        }
        
        print("Capture session setup complete")
    }
    
    func startScanning() {
        print("Starting scanning...")
        hasScanned = false
        scannedCode = nil
        
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                print("Session started running")
            }
        }
    }
    
    func stopScanning() {
        print("Stopping scanning...")
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
                print("Session stopped running")
            }
        }
    }
}

extension BarcodeScannerManager: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Only scan once
            if !hasScanned {
                print("Barcode detected: \(stringValue)")
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                hasScanned = true
                scannedCode = stringValue
                stopScanning()
            }
        }
    }
}

// MARK: - Camera Preview (same as before)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                layer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Search Results View (same as before, already provided)
struct SearchResultsView: View {
    let scannedCode: String
    let results: [InventoryItem]
    @ObservedObject var viewModel: InventoryViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: InventoryItem?
    
    var body: some View {
        VStack {
            // Show what was scanned
            HStack {
                Image(systemName: "barcode")
                    .font(.title2)
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("Scanned Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(scannedCode)
                        .font(.headline)
                }
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding()
            
            // Results
            if results.isEmpty {
                ContentUnavailableView(
                    "No Items Found",
                    systemImage: "magnifyingglass",
                    description: Text("No products match the scanned code '\(scannedCode)'")
                )
            } else {
                List(results) { item in
                    Button(action: {
                        selectedItem = item
                    }) {
                        InventoryRow(item: item)
                    }
                }
            }
        }
        .navigationTitle("Search Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    isPresented = false
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationView {
                ProductDetailView(viewModel: viewModel, item: item)
            }
        }
    }
}
