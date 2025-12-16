//
//  AddSalesView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI
import CoreData

struct AddSalesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let item: InventoryItem
    
    @State private var quantity = ""
    @State private var saleDate = Date()
    @State private var orderNumber = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sale Details") {
                    Text("Item: \(item.name ?? "Unknown")")
                        .font(.headline)
                    
                    TextField("Quantity Sold", text: $quantity)
                        .keyboardType(.numberPad)
                    
                    DatePicker("Sale Date", selection: $saleDate, displayedComponents: [.date])
                    
                    TextField("Order Number (Optional)", text: $orderNumber)
                }
            }
            .navigationTitle("Add Sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSale()
                    }
                    .disabled(quantity.isEmpty)
                }
            }
        }
    }
    
    private func saveSale() {
        guard let qty = Int32(quantity) else { return }
        
        let sale = SalesHistory(context: viewContext)
        sale.id = Int32(Date().timeIntervalSince1970)
        sale.soldQuantity = qty
        sale.saleDate = saleDate
        sale.orderNumber = orderNumber.isEmpty ? nil : orderNumber
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving sale: \(error)")
        }
    }
}
