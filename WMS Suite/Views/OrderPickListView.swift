//
//  OrderPickListView.swift
//  WMS Suite
//
//  Enhanced with inventory deduction on pick
//

import SwiftUI
import CoreData

struct OrderPickListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let sale: Sale
    
    @State private var pickedQuantities: [Int32: Decimal] = [:] // lineItemId: pickedQty
    @State private var showingPickSheet = false
    @State private var selectedLineItem: SaleLineItem?
    
    var lineItems: [SaleLineItem] {
        guard let items = sale.lineItems as? Set<SaleLineItem> else { return [] }
        return Array(items).sorted { ($0.item?.name ?? "") < ($1.item?.name ?? "") }
    }
    
    var allItemsPicked: Bool {
        return lineItems.allSatisfy { lineItem in
            let picked = pickedQuantities[lineItem.id] ?? 0
            return picked >= lineItem.quantity
        }
    }
    
    var totalPicked: Int {
        lineItems.filter { lineItem in
            let picked = pickedQuantities[lineItem.id] ?? 0
            return picked >= lineItem.quantity
        }.count
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
                    Text("\(totalPicked)/\(lineItems.count)")
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
                                pickedQuantity: pickedQuantities[lineItem.id] ?? 0,
                                onTap: {
                                    selectedLineItem = lineItem
                                    showingPickSheet = true
                                }
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPickSheet) {
            if let lineItem = selectedLineItem, let item = lineItem.item {
                NavigationView {
                    PickItemSheet(lineItem: lineItem, item: item) { pickedQty in
                        // Update picked quantity
                        let currentPicked = pickedQuantities[lineItem.id] ?? 0
                        pickedQuantities[lineItem.id] = currentPicked + pickedQty
                    }
                }
            } else {
                NavigationView {
                    VStack {
                        Text("Error: Could not load item")
                            .foregroundColor(.red)
                        Button("Close") {
                            showingPickSheet = false
                        }
                    }
                    .navigationTitle("Error")
                }
            }
        }
    }
}

// MARK: - Pick List Item Row

struct PickListItemRow: View {
    let lineItem: SaleLineItem
    let item: InventoryItem
    let pickedQuantity: Decimal
    let onTap: () -> Void
    
    var isFullyPicked: Bool {
        pickedQuantity >= lineItem.quantity
    }
    
    var isPartiallyPicked: Bool {
        pickedQuantity > 0 && pickedQuantity < lineItem.quantity
    }
    
    var hasStockIssue: Bool {
        item.quantity < lineItem.quantity
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status Icon
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .frame(width: 30)
                
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
                        if hasStockIssue {
                            Label("\(item.quantity) available", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Pick progress
                    if isPartiallyPicked {
                        Text("Picked: \(pickedQuantity) of \(lineItem.quantity)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Quantity badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("×\(lineItem.quantity)")
                        .font(.title3)
                        .bold()
                        .foregroundColor(statusColor)
                    
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        if isFullyPicked {
            return "checkmark.circle.fill"
        } else if isPartiallyPicked {
            return "circle.lefthalf.filled"
        } else {
            return "circle"
        }
    }
    
    private var statusColor: Color {
        if isFullyPicked {
            return .green
        } else if isPartiallyPicked {
            return .blue
        } else if hasStockIssue {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if isFullyPicked {
            return "picked"
        } else if isPartiallyPicked {
            return "partial"
        } else {
            return "needed"
        }
    }
    
    private var backgroundColor: Color {
        if isFullyPicked {
            return Color.green.opacity(0.1)
        } else if isPartiallyPicked {
            return Color.blue.opacity(0.1)
        } else {
            return Color(.secondarySystemBackground)
        }
    }
    
    private var borderColor: Color {
        if isFullyPicked {
            return .green
        } else if isPartiallyPicked {
            return .blue
        } else {
            return .clear
        }
    }
}

