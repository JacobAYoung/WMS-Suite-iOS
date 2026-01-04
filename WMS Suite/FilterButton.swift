//
//  FilterButton.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
//

import SwiftUI

struct FilterButton: View {
    @Binding var selectedFilter: InventoryFilterOption
    @Binding var showingTagPicker: Bool
    
    var body: some View {
        Menu {
            ForEach(InventoryFilterOption.allCases) { filter in
                Button(action: {
                    if filter == .byTag {
                        showingTagPicker = true
                    } else {
                        selectedFilter = filter
                    }
                }) {
                    HStack {
                        Label(filter.rawValue, systemImage: filter.icon)
                        if selectedFilter == filter {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: selectedFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(selectedFilter == .all ? .primary : .blue)
        }
    }
}
