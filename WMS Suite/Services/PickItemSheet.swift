//
//  PickItemSheet.swift
//  WMS Suite
//
//  Sheet for picking items with inventory deduction
//  Handles partial picks and stock validation
//

import SwiftUI
import CoreData

struct PickItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let lineItem: SaleLineItem
    let item: InventoryItem
    let onPicked: (Decimal) -> Void
    
    @State private var quantityToPick: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var isQuantityFocused: Bool
    
    init(lineItem: SaleLineItem, item: InventoryItem, onPicked: @escaping (Decimal) -> Void) {
        self.lineItem = lineItem
        self.item = item
        self.onPicked = onPicked
        
        // Get quantities as Decimal for comparison
        let lineQty: Decimal
        if let decimalNumber = lineItem.quantity as? NSDecimalNumber {
            lineQty = decimalNumber.decimalValue
        } else if let decimal = lineItem.quantity as? Decimal {
            lineQty = decimal
        } else {
            lineQty = 0
        }
        
        let itemQty: Decimal
        if let decimalNumber = item.quantity as? NSDecimalNumber {
            itemQty = decimalNumber.decimalValue
        } else if let decimal = item.quantity as? Decimal {
            itemQty = decimal
        } else {
            itemQty = 0
        }
        
        // Default to full quantity if available, otherwise available stock
        let defaultQty = min(lineQty, itemQty)
        
        // Format decimal nicely (remove trailing zeros)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let formattedQty = formatter.string(from: NSDecimalNumber(decimal: defaultQty)) ?? "\(defaultQty)"
        _quantityToPick = State(initialValue: formattedQty)
    }
    
    var quantityNeeded: Decimal {
        // Handle both NSDecimalNumber and Decimal types
        if let decimalNumber = lineItem.quantity as? NSDecimalNumber {
            return decimalNumber.decimalValue
        } else if let decimal = lineItem.quantity as? Decimal {
            return decimal
        }
        return 0
    }
    
    var availableStock: Decimal {
        // Handle both NSDecimalNumber and Decimal types
        if let decimalNumber = item.quantity as? NSDecimalNumber {
            return decimalNumber.decimalValue
        } else if let decimal = item.quantity as? Decimal {
            return decimal
        }
        return 0
    }
    
    var hasEnoughStock: Bool {
        availableStock >= quantityNeeded
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Item Info Card
                itemInfoCard
                
                // Stock Status
                stockStatusCard
                
                // Quantity Picker
                quantityPickerCard
                
                // Pick Button
                pickButton
            }
            .padding()
        }
        .navigationTitle("Pick Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isQuantityFocused = true
            }
        }
    }
    
    // MARK: - Item Info Card
    
    private var itemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.name ?? "Unknown Item")
                .font(.title2)
                .fontWeight(.bold)
            
            if let sku = item.sku {
                HStack {
                    Image(systemName: "barcode")
                        .foregroundColor(.secondary)
                    Text("SKU: \(sku)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Stock Status Card
    
    private var stockStatusCard: some View {
        VStack(spacing: 16) {
            // Quantity Needed
            HStack {
                Label("Quantity Needed", systemImage: "cart")
                    .foregroundColor(.primary)
                Spacer()
                Text("\(quantityNeeded)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Divider()
            
            // Available Stock
            HStack {
                Label("Available Stock", systemImage: "cube.box")
                    .foregroundColor(.primary)
                Spacer()
                Text(formatQuantity(availableStock))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(hasEnoughStock ? .green : .red)
            }
            
            // Warning if insufficient stock
            if !hasEnoughStock && availableStock > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Insufficient stock - partial pick only")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else if availableStock == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Out of stock - cannot pick")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Sufficient stock available")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Quantity Picker Card
    
    private var quantityPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quantity to Pick")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Minus button
                Button(action: {
                    if let current = Decimal(string: quantityToPick), current > 1 {
                        let formatter = NumberFormatter()
                        formatter.minimumFractionDigits = 0
                        formatter.maximumFractionDigits = 2
                        quantityToPick = formatter.string(from: NSDecimalNumber(decimal: current - 1)) ?? "\(current - 1)"
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                }
                .disabled(quantityToPick == "1" || quantityToPick == "0")
                
                // Quantity input
                TextField("Qty", text: $quantityToPick)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: 120)
                    .focused($isQuantityFocused)
                
                // Plus button
                Button(action: {
                    if let current = Decimal(string: quantityToPick), current < availableStock {
                        let formatter = NumberFormatter()
                        formatter.minimumFractionDigits = 0
                        formatter.maximumFractionDigits = 2
                        quantityToPick = formatter.string(from: NSDecimalNumber(decimal: current + 1)) ?? "\(current + 1)"
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }
                .disabled((Decimal(string: quantityToPick) ?? 0) >= availableStock)
            }
            .frame(maxWidth: .infinity)
            
            // Quick pick buttons
            HStack(spacing: 12) {
                if availableStock > 0 {
                    let formatter = NumberFormatter()
                    formatter.minimumFractionDigits = 0
                    formatter.maximumFractionDigits = 2
                    
                    QuickPickButton(title: "Max", value: min(quantityNeeded, availableStock)) {
                        let val = min(quantityNeeded, availableStock)
                        quantityToPick = formatter.string(from: NSDecimalNumber(decimal: val)) ?? "\(val)"
                    }
                    
                    if availableStock >= quantityNeeded {
                        QuickPickButton(title: "All", value: quantityNeeded) {
                            quantityToPick = formatter.string(from: NSDecimalNumber(decimal: quantityNeeded)) ?? "\(quantityNeeded)"
                        }
                    }
                    
                    if availableStock > 1 {
                        let halfVal = availableStock / 2
                        QuickPickButton(title: "Half", value: halfVal) {
                            quantityToPick = formatter.string(from: NSDecimalNumber(decimal: halfVal)) ?? "\(halfVal)"
                        }
                    }
                }
            }
            
            // Validation message
            if let qty = Decimal(string: quantityToPick), qty > availableStock {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Cannot pick more than available stock (\(formatQuantity(availableStock)))")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Pick Button
    
    private var pickButton: some View {
        Button(action: pickItem) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(isPartialPick ? "Pick Partial (\(quantityToPick) of \(quantityNeeded))" : "Pick & Deduct from Inventory")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValidPick ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isValidPick)
    }
    
    // MARK: - Computed Properties
    
    private var isPartialPick: Bool {
        guard let qty = Decimal(string: quantityToPick) else { return false }
        return qty < quantityNeeded
    }
    
    private var isValidPick: Bool {
        guard let qty = Decimal(string: quantityToPick) else { return false }
        return qty > 0 && qty <= availableStock
    }
    
    // MARK: - Actions
    
    private func pickItem() {
        guard let quantity = Decimal(string: quantityToPick), quantity > 0 else {
            errorMessage = "Please enter a valid quantity"
            showingError = true
            return
        }
        
        guard quantity <= availableStock else {
            errorMessage = "Cannot pick \(formatQuantity(quantity)) items. Only \(formatQuantity(availableStock)) available."
            showingError = true
            return
        }
        
        // Deduct from inventory
        Task { @MainActor in
            do {
                try await viewContext.perform {
                    // Get current quantity as Decimal
                    let currentQty: Decimal
                    if let decimalNumber = item.quantity as? NSDecimalNumber {
                        currentQty = decimalNumber.decimalValue
                    } else if let decimal = item.quantity as? Decimal {
                        currentQty = decimal
                    } else {
                        currentQty = 0
                    }
                    
                    // Update quantity
                    item.quantity = NSDecimalNumber(decimal: currentQty - quantity)
                    item.lastUpdated = Date()
                    
                    try viewContext.save()
                }
                
                // Log the pick
                print("""
                📦 ITEM PICKED:
                - Item: \(item.name ?? "Unknown")
                - Quantity: \(quantity)
                - Remaining Stock: \(item.quantity)
                - Needed: \(quantityNeeded)
                - Partial: \(isPartialPick)
                """)
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Call completion handler
                onPicked(quantity)
                
                dismiss()
                
            } catch {
                errorMessage = "Error updating inventory: \(error.localizedDescription)"
                showingError = true
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

// MARK: - Quick Pick Button

struct QuickPickButton: View {
    let title: String
    let value: Decimal
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
                let valueString = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
                
                Text(valueString)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
