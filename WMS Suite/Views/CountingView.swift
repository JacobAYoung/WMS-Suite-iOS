//
//  CountingView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI
import AVFoundation
import Vision

struct CountingView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @StateObject private var cameraManager = CameraManager()
    @State private var showingCamera = false
    @State private var detectedCount = 0
    @State private var manualCount = 0
    @State private var isProcessing = false
    @State private var selectedItem: InventoryItem?
    @State private var showingUpdateConfirmation = false
    @State private var useManualCount = false
    
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationView {
            if isIPad && cameraManager.capturedImage != nil {
                // iPad: Side-by-side layout
                HStack(spacing: 0) {
                    // Left: Image and count
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(uiImage: cameraManager.capturedImage!)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .padding()
                            
                            countAdjustmentSection
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Right: Inventory selection and update
                    inventoryUpdateSection
                        .frame(width: 400)
                }
                .navigationTitle("AI Counting")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: retakePhoto) {
                            Label("Retake", systemImage: "camera.rotate")
                        }
                    }
                }
            } else {
                // iPhone or no image: Original layout
                VStack {
                    if cameraManager.capturedImage != nil {
                        ScrollView {
                            VStack(spacing: 20) {
                                Image(uiImage: cameraManager.capturedImage!)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                                
                                countAdjustmentSection
                                    .padding(.horizontal)
                                
                                inventoryUpdateSection
                                    .padding()
                            }
                            .padding()
                        }
                    } else {
                        initialCameraView
                    }
                }
                .navigationTitle("AI Counting")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingCamera) {
            CameraViewWrapper(cameraManager: cameraManager, isProcessing: $isProcessing, detectedCount: $detectedCount)
        }
        .alert("Inventory Updated", isPresented: $showingUpdateConfirmation) {
            Button("OK", role: .cancel) {
                cameraManager.capturedImage = nil
                selectedItem = nil
                detectedCount = 0
                manualCount = 0
                useManualCount = false
            }
        } message: {
            let finalCount = useManualCount ? manualCount : detectedCount
            Text("Successfully added \(finalCount) items to inventory")
        }
        .onChange(of: detectedCount) { _, newValue in
            manualCount = newValue
            useManualCount = false
        }
    }
    
    // MARK: - View Components
    
    var countAdjustmentSection: some View {
        VStack(spacing: 16) {
            // AI Detected Count
            HStack {
                Image(systemName: "cube.box")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("AI Detected")
                    .font(.headline)
                Spacer()
                Text("\(detectedCount)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Manual Adjustment
            VStack(spacing: 12) {
                Text("Adjust Count Manually")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    Button(action: {
                        if manualCount > 0 {
                            manualCount -= 1
                            useManualCount = true
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.red)
                    }
                    
                    Text("\(manualCount)")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(minWidth: 100)
                    
                    Button(action: {
                        manualCount += 1
                        useManualCount = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                    }
                }
                
                Button("Reset to AI Count") {
                    manualCount = detectedCount
                    useManualCount = false
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Analyzing image...")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
    
    var inventoryUpdateSection: some View {
        VStack(spacing: 12) {
            Text("Update Inventory")
                .font(.headline)
            
            Picker("Select Item", selection: $selectedItem) {
                Text("Choose an item").tag(nil as InventoryItem?)
                ForEach(viewModel.items) { item in
                    Text("\(item.name ?? "Unknown") (\(item.sku ?? ""))").tag(item as InventoryItem?)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            if let item = selectedItem {
                let finalCount = useManualCount ? manualCount : detectedCount
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Quantity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(item.quantity)")
                            .font(.title2)
                            .bold()
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.green)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        Text("New Quantity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(item.quantity + Int32(finalCount))")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                if useManualCount {
                    Text("Using manual count: \(manualCount)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Button(action: updateInventory) {
                let finalCount = useManualCount ? manualCount : detectedCount
                Label("Update Inventory (+\(finalCount))", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedItem != nil ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(selectedItem == nil)
            
            if !isIPad {
                Button(action: retakePhoto) {
                    Label("Retake Photo", systemImage: "camera.rotate")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    var initialCameraView: some View {
        VStack(spacing: 30) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("AI-Powered Counting")
                    .font(.title2)
                    .bold()
                
                Text("Take a photo of items to automatically count them")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Place items in a well-lit area", systemImage: "sun.max")
                Label("Spread items apart for better detection", systemImage: "square.grid.3x3")
                Label("Hold camera steady when capturing", systemImage: "hand.raised")
                Label("You can manually adjust the count after", systemImage: "hand.tap")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Button(action: { showingCamera = true }) {
                Label("Open Camera", systemImage: "camera")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func retakePhoto() {
        cameraManager.capturedImage = nil
        detectedCount = 0
        manualCount = 0
        selectedItem = nil
        useManualCount = false
        showingCamera = true
    }
    
    private func updateInventory() {
        guard let item = selectedItem else { return }
        
        let finalCount = useManualCount ? manualCount : detectedCount
        let newQuantity = item.quantity + Int32(finalCount)
        
        viewModel.updateItem(
            item,
            sku: item.sku ?? "",
            name: item.name ?? "",
            description: item.itemDescription,
            upc: item.upc,
            webSKU: item.webSKU,
            quantity: newQuantity,
            minStockLevel: item.minStockLevel
        )
        
        showingUpdateConfirmation = true
    }
}
