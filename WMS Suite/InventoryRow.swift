//
//  InventoryRow.swift
//  WMS Suite
//
//  Row view for inventory list items
//

import SwiftUI

struct InventoryRow: View {
    let item: InventoryItem
    
    private var stockStatus: (color: Color, icon: String) {
        if item.quantity == 0 {
            return (.red, "xmark.circle.fill")
        } else if item.quantity < item.minStockLevel {
            return (.orange, "exclamationmark.triangle.fill")
        } else {
            return (.green, "checkmark.circle.fill")
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            if let imageUrl = item.displayImageUrl {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                    case .failure, .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
            
            // Item Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let sku = item.sku, !sku.isEmpty {
                        Text("SKU: \(sku)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Source badges
                    if item.existsIn(.shopify) {
                        Image(systemName: "cart.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    if item.existsIn(.quickbooks) {
                        Image(systemName: "book.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Quantity & Status
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: stockStatus.icon)
                        .font(.caption)
                        .foregroundColor(stockStatus.color)
                    Text("\(item.quantity)")
                        .font(.headline)
                        .foregroundColor(stockStatus.color)
                }
                
                if item.minStockLevel > 0 {
                    Text("Min: \(item.minStockLevel)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Needs sync indicator
            if item.needsShopifySync || item.needsQuickBooksSync {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }
}
