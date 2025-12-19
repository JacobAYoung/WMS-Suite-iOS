//
//  AddSalesView.swift
//  WMS Suite
//
//  Updated to set order source when creating sales
//

import SwiftUI
import CoreData

struct AddSalesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Optional: pre-select an item
    let preselectedItem: InventoryItem?
    
    @State private var saleDate = Date()
    @State private var orderNumber = ""
    @State private var lineItems: [LineItemInput] = []
    @State private var showingAddLineItem = false
    
    // For available items
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \InventoryItem.name, ascending: true)],
        animation: .default)
    private var availableItems: FetchedResults<InventoryItem>
    
    init(preselectedItem: InventoryItem? = nil) {
        self.preselectedItem = preselectedItem
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sale Details") {
                    DatePicker("Sale Date", selection: $saleDate, displayedComponents: [.date])
                    TextField("Order Number (Optional)", text: $orderNumber)
                }
                
                Section {
                    ForEach(lineItems.indices, id: \.self) { index in
                        LineItemRow(lineItem: lineItems[index]) {
                            lineItems.remove(at: index)
                        }
                    }
                    .onDelete { indexSet in
                        lineItems.remove(atOffsets: indexSet)
                    }
                    
                    Button(action: { showingAddLineItem = true }) {
                        Label("Add Item", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Items Sold")
                } footer: {
                    if !lineItems.isEmpty {
                        Text("Total Items: \(lineItems.reduce(0) { $0 + $1.quantity })")
                    }
                }
            }
            .navigationTitle("Add Order")
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
                    .disabled(lineItems.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddLineItem) {
                AddLineItemView(availableItems: Array(availableItems)) { lineItem in
                    lineItems.append(lineItem)
                }
            }
            .onAppear {
                // If there's a preselected item, add it automatically
                if let item = preselectedItem {
                    lineItems.append(LineItemInput(item: item, quantity: 1))
                }
            }
        }
    }
    
    private func saveSale() {
        // Create the Sale
        let sale = Sale(context: viewContext)
        sale.id = Int32(Date().timeIntervalSince1970)
        sale.saleDate = saleDate
        sale.orderNumber = orderNumber.isEmpty ? nil : orderNumber
        
        // ✅ NEW: Set source to local for manually created orders
        sale.setSource(.local)
        
        // Create line items
        for (index, lineItemInput) in lineItems.enumerated() {
            let lineItem = SaleLineItem(context: viewContext)
            lineItem.id = Int32(Date().timeIntervalSince1970 + Double(index))
            lineItem.quantity = lineItemInput.quantity
            lineItem.sale = sale
            lineItem.item = lineItemInput.item
            
            // Optional: Update inventory quantity
            lineItemInput.item.quantity -= lineItemInput.quantity
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving sale: \(error)")
        }
    }
}

// MARK: - Line Item Input Model
struct LineItemInput: Identifiable {
    let id = UUID()
    let item: InventoryItem
    var quantity: Int32
}

// MARK: - Line Item Row
struct LineItemRow: View {
    let lineItem: LineItemInput
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(lineItem.item.name ?? "Unknown")
                    .font(.headline)
                Text("SKU: \(lineItem.item.sku ?? "N/A")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("×\(lineItem.quantity)")
                .font(.title3)
                .bold()
                .foregroundColor(.blue)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Line Item View
struct AddLineItemView: View {
    @Environment(\.dismiss) private var dismiss
    let availableItems: [InventoryItem]
    let onAdd: (LineItemInput) -> Void
    
    @State private var selectedItem: InventoryItem?
    @State private var quantity: String = "1"
    @State private var searchText = ""
    
    var filteredItems: [InventoryItem] {
        if searchText.isEmpty {
            return availableItems
        }
        return availableItems.filter { item in
            (item.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (item.sku?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search items...", text: $searchText)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                // Item list
                List(filteredItems) { item in
                    Button(action: {
                        selectedItem = item
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Unknown")
                                    .font(.headline)
                                Text("SKU: \(item.sku ?? "N/A")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedItem == item {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Quantity picker (shown when item selected)
                if selectedItem != nil {
                    VStack(spacing: 12) {
                        Text("Quantity")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                if let qty = Int32(quantity), qty > 1 {
                                    quantity = "\(qty - 1)"
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                            }
                            
                            TextField("Qty", text: $quantity)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title)
                                .frame(width: 80)
                            
                            Button(action: {
                                if let qty = Int32(quantity) {
                                    quantity = "\(qty + 1)"
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                }
            }
            .navigationTitle("Add Item to Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addLineItem()
                    }
                    .disabled(selectedItem == nil || quantity.isEmpty)
                }
            }
        }
    }
    
    private func addLineItem() {
        guard let item = selectedItem,
              let qty = Int32(quantity) else { return }
        
        onAdd(LineItemInput(item: item, quantity: qty))
        dismiss()
    }
}
