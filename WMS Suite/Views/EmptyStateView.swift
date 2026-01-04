//
//  EmptyStateView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
//


import SwiftUI

struct EmptyStateView: View {
    let searchText: String
    @Binding var selectedFilter: InventoryFilterOption
    @Binding var showingAddItem: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty && selectedFilter == .all {
                // No items at all
                Image(systemName: "shippingbox")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                
                Text("No Inventory Items")
                    .font(.title2)
                    .bold()
                
                Text("Add your first item to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: { showingAddItem = true }) {
                    Label("Add Item", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                // Filtered/searched but no results
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                
                Text("No Results")
                    .font(.title2)
                    .bold()
                
                if !searchText.isEmpty {
                    Text("No items match \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if selectedFilter != .all {
                    Text("Try a different filter")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Clear Filter") {
                        selectedFilter = .all
                    }
                    .padding()
                }
            }
        }
        .padding()
    }
}
