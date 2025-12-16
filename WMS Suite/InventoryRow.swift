//
//  InventoryRow.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI

struct InventoryRow: View {
    let item: InventoryItem
    
    var stockStatus: (String, Color) {
        let qty = item.quantity
        if qty == 0 {
            return ("Out of Stock", .red)
        } else if qty < (item.minStockLevel > 0 ? item.minStockLevel : 10) {
            return ("Low Stock", .orange)
        } else {
            return ("In Stock", .green)
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "No Name")
                    .font(.headline)
                
                HStack {
                    Text("SKU: \(item.sku ?? "N/A")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(stockStatus.0)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(stockStatus.1)
                        .cornerRadius(4)
                }
                
                HStack(spacing: 8) {
                    Text("Qty: \(item.quantity)")
                        .font(.subheadline)
                    
                    // Source badges
                    ForEach(item.itemSources, id: \.self) { source in
                        Image(systemName: source.iconName)
                            .font(.caption)
                            .foregroundColor(source.color)
                    }
                    
                    Spacer()
                    
                    if let updated = item.lastUpdated {
                        Text(updated, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
