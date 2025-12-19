//
//  ActiveFiltersBar.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
//


import SwiftUI

struct ActiveFiltersBar: View {
    @Binding var selectedFilter: InventoryFilterOption
    @Binding var selectedSort: InventorySortOption
    let itemCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            if selectedFilter != .all {
                FilterPill(
                    icon: selectedFilter.icon,
                    text: selectedFilter.rawValue,
                    color: .blue,
                    onRemove: { selectedFilter = .all }
                )
            }
            
            if selectedSort != .nameAZ {
                FilterPill(
                    icon: selectedSort.icon,
                    text: selectedSort.rawValue,
                    color: .green,
                    onRemove: { selectedSort = .nameAZ }
                )
            }
            
            Spacer()
            
            Text("\(itemCount) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

struct FilterPill: View {
    let icon: String
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(15)
    }
}
