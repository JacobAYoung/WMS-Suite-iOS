//
//  AddItemView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI

struct AddItemView: View {
    @ObservedObject var viewModel: InventoryViewModel
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
                    TextField("SKU *", text: $sku)
                        .textInputAutocapitalization(.characters)
                    TextField("Name *", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section("Product Details") {
                    TextField("UPC/Barcode", text: $upc)
                        .keyboardType(.numberPad)
                    TextField("Web SKU (Optional)", text: $webSKU)
                        .textInputAutocapitalization(.characters)
                    TextField("Quantity *", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Min Stock Level", text: $minStock)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !sku.isEmpty && !name.isEmpty && !quantity.isEmpty
    }
    
    private func saveItem() {
        guard let qty = Decimal(string: quantity) else { return }
        let minStockDecimal = Decimal(string: minStock) ?? 0
        
        viewModel.addItem(
            sku: sku,
            name: name,
            description: description.isEmpty ? nil : description,
            upc: upc.isEmpty ? nil : upc,
            webSKU: webSKU.isEmpty ? nil : webSKU,
            quantity: qty,
            minStockLevel: minStockDecimal
        )
        isPresented = false
    }
}
