//
//  OrderPickListView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/19/25.
//

import SwiftUI

struct OrderPickListView: View {
    let sale: Sale
    @State private var checkedItems: Set<Int32> = []
    
    var lineItems: [SaleLineItem] {
        guard let items = sale.lineItems as? Set<SaleLineItem> else { return [] }
        return Array(items).sorted { ($0.item?.name ?? "") < ($1.item?.name ?? "") }
    }
    
    var allItemsPicked: Bool {
        return checkedItems.count == lineItems.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items to Pick")
                    .font(.headline)
                
                Spacer()
                
                if allItemsPicked {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Complete")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                } else {
                    Text("\(checkedItems.count)/\(lineItems.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if lineItems.isEmpty {
                Text("No items in this order")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(lineItems, id: \.id) { lineItem in
                        if let item = lineItem.item {
                            PickListItemRow(
                                lineItem: lineItem,
                                item: item,
                                isChecked: checkedItems.contains(lineItem.id),
                                onToggle: {
                                    toggleItem(lineItem.id)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func toggleItem(_ itemId: Int32) {
        if checkedItems.contains(itemId) {
            checkedItems.remove(itemId)
        } else {
            checkedItems.insert(itemId)
        }
    }
}

// MARK: - Pick List Item Row

struct PickListItemRow: View {
    let lineItem: SaleLineItem
    let item: InventoryItem
    let isChecked: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundColor(isChecked ? .green : .gray)
                
                // Item info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? "Unknown Item")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        if let sku = item.sku {
                            Text("SKU: \(sku)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show available stock
                        if item.quantity < lineItem.quantity {
                            Label("\(item.quantity) available", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                // Quantity badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("×\(lineItem.quantity)")
                        .font(.title3)
                        .bold()
                        .foregroundColor(isChecked ? .green : .blue)
                    
                    Text("needed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(isChecked ? Color.green.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isChecked ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
