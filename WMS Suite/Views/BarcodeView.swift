//
//  BarcodeView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI

struct BarcodeView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedItem: InventoryItem?
    @State private var generatedBarcode: BarcodeData?
    @State private var printCopies = 1
    @State private var showingPrintSuccess = false
    @State private var showingSaveSheet = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationView {
            if isIPad {
                // iPad: Side-by-side layout
                HStack(spacing: 0) {
                    // Left side: Item selection
                    List(viewModel.items) { item in
                        Button(action: {
                            selectedItem = item
                            generateBarcode(for: item)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Unknown")
                                    .font(.headline)
                                Text("SKU: \(item.sku ?? "N/A")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(width: 300)
                    
                    Divider()
                    
                    // Right side: Barcode display
                    if let barcodeData = generatedBarcode {
                        BarcodeDetailView(
                            barcodeData: barcodeData,
                            printCopies: $printCopies,
                            showingPrintSuccess: $showingPrintSuccess,
                            showingSaveSheet: $showingSaveSheet,
                            printAction: printBarcode
                        )
                    } else {
                        VStack {
                            Image(systemName: "barcode")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                            Text("Select an item to generate barcode")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                // iPhone: Original form layout
                Form {
                    Section("Select Item") {
                        Picker("Item", selection: $selectedItem) {
                            Text("Choose an item").tag(nil as InventoryItem?)
                            ForEach(viewModel.items) { item in
                                Text("\(item.name ?? "Unknown") - \(item.sku ?? "")").tag(item as InventoryItem?)
                            }
                        }
                        .onChange(of: selectedItem) { _, newValue in
                            if let item = newValue {
                                generateBarcode(for: item)
                            } else {
                                generatedBarcode = nil
                            }
                        }
                    }
                    
                    if let barcodeData = generatedBarcode {
                        Section("Generated Barcode") {
                            VStack(spacing: 12) {
                                Image(uiImage: barcodeData.image)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .background(Color(uiColor: .systemBackground))
                                    .cornerRadius(8)
                                
                                Text(barcodeData.data)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(barcodeData.item.name ?? "Unknown Item")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                        }
                        
                        Section("Print Options") {
                            Stepper("Copies: \(printCopies)", value: $printCopies, in: 1...100)
                            
                            Button(action: printBarcode) {
                                HStack {
                                    Image(systemName: "printer")
                                    Text("Print Barcode")
                                }
                            }
                            
                            Button(action: { showingSaveSheet = true }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save Image")
                                }
                            }
                        }
                        
                        Section("Item Details") {
                            LabeledContent("SKU", value: barcodeData.item.sku ?? "N/A")
                            LabeledContent("Name", value: barcodeData.item.name ?? "N/A")
                            if let upc = barcodeData.item.upc {
                                LabeledContent("UPC", value: upc)
                            }
                            LabeledContent("Quantity", value: "\(barcodeData.item.quantity)")
                        }
                    }
                }
            }
        }
        .navigationTitle("Barcodes")
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("Print Queued", isPresented: $showingPrintSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(printCopies) barcode(s) sent to printer")
        }
        .sheet(isPresented: $showingSaveSheet) {
            if let barcodeData = generatedBarcode {
                ActivityViewController(activityItems: [barcodeData.image])
            }
        }
    }
    
    private func generateBarcode(for item: InventoryItem) {
        generatedBarcode = viewModel.generateBarcode(for: item)
    }
    
    private func printBarcode() {
        guard let barcodeData = generatedBarcode else { return }
        viewModel.printBarcode(barcodeData, copies: printCopies)
        showingPrintSuccess = true
    }
}

// MARK: - Barcode Detail View (Reusable for iPad)
struct BarcodeDetailView: View {
    let barcodeData: BarcodeData
    @Binding var printCopies: Int
    @Binding var showingPrintSuccess: Bool
    @Binding var showingSaveSheet: Bool
    let printAction: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Barcode Image
                VStack(spacing: 12) {
                    Image(uiImage: barcodeData.image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                    
                    Text(barcodeData.data)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(barcodeData.item.name ?? "Unknown Item")
                        .font(.title2)
                        .bold()
                }
                .padding()
                
                // Item Details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Item Details")
                        .font(.headline)
                    
                    InfoRow(label: "SKU", value: barcodeData.item.sku ?? "N/A")
                    InfoRow(label: "Name", value: barcodeData.item.name ?? "N/A")
                    if let upc = barcodeData.item.upc {
                        InfoRow(label: "UPC", value: upc)
                    }
                    InfoRow(label: "Quantity", value: "\(barcodeData.item.quantity)")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Print Controls
                VStack(spacing: 16) {
                    HStack {
                        Text("Copies:")
                            .font(.headline)
                        Spacer()
                        HStack(spacing: 20) {
                            Button(action: {
                                if printCopies > 1 {
                                    printCopies -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                            }
                            
                            Text("\(printCopies)")
                                .font(.title)
                                .bold()
                                .frame(minWidth: 50)
                            
                            Button(action: {
                                if printCopies < 100 {
                                    printCopies += 1
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Button(action: printAction) {
                        HStack {
                            Image(systemName: "printer.fill")
                            Text("Print Barcode")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: { showingSaveSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Image")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }
}
