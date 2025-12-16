//
//  EditItemView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI

struct EditItemView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let item: InventoryItem
    @Binding var isPresented: Bool
    
    @State private var sku = ""
    @State private var name = ""
    @State private var description = ""
    @State private var upc = ""
    @State private var webSKU = ""
    @State private var quantity = ""
    @State private var minStock = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("SKU", text: $sku)
                        .textInputAutocapitalization(.characters)
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Product Details") {
                    TextField("UPC/Barcode", text: $upc)
                        .keyboardType(.numberPad)
                    TextField("Web SKU (Optional)", text: $webSKU)
                        .textInputAutocapitalization(.characters)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    TextField("Min Stock Level", text: $minStock)
                        .keyboardType(.numberPad)
                }
                
                Section("Metadata") {
                    if let updated = item.lastUpdated {
                        HStack {
                            Text("Last Updated")
                            Spacer()
                            Text(updated, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                loadItemData()
            }
        }
    }
    
    private func loadItemData() {
        sku = item.sku ?? ""
        name = item.name ?? ""
        description = item.itemDescription ?? ""
        upc = item.upc ?? ""
        webSKU = item.webSKU ?? ""
        quantity = "\(item.quantity)"
        minStock = "\(item.minStockLevel)"
    }
    
    private func saveChanges() {
        guard let qty = Int32(quantity) else { return }
        let minStockInt = Int32(minStock) ?? 0
        
        viewModel.updateItem(
            item,
            sku: sku,
            name: name,
            description: description.isEmpty ? nil : description,
            upc: upc.isEmpty ? nil : upc,
            webSKU: webSKU.isEmpty ? nil : webSKU,
            quantity: qty,
            minStockLevel: minStockInt
        )
        isPresented = false
    }
}
