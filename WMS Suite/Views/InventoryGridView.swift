//
//  InventoryGridView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import SwiftUI

struct InventoryGridView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let items: [InventoryItem]
    
    let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(destination: ProductDetailView(viewModel: viewModel, item: item)) {
                        InventoryGridCard(item: item)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct InventoryGridCard: View {
    let item: InventoryItem
    @Environment(\.colorScheme) var colorScheme
    
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
    
    var cardBackground: Color {
        colorScheme == .dark ? Color(uiColor: .systemGray6) : .white
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Product Image
            ZStack {
                if let imageUrl = item.displayImageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 140)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 140)
                                .clipped()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .frame(height: 140)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                }
            }
            .cornerRadius(8)
            
            // Product Info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name ?? "Unknown")
                    .font(.headline)
                    .lineLimit(2)
                
                Text("SKU: \(item.sku ?? "N/A")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Qty: \(item.quantity)")
                        .font(.subheadline)
                        .bold()
                    
                    Spacer()
                    
                    Text(stockStatus.0)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(stockStatus.1)
                        .cornerRadius(4)
                }
                
                // Source badges
                HStack(spacing: 4) {
                    ForEach(item.itemSources, id: \.self) { source in
                        Image(systemName: source.iconName)
                            .font(.caption2)
                            .foregroundColor(source.color)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
