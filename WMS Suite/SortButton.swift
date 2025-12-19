//
//  SortButton.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
//

import SwiftUI

struct SortButton: View {
    @Binding var selectedSort: InventorySortOption
    
    var body: some View {
        Menu {
            ForEach(InventorySortOption.allCases) { sort in
                Button(action: {
                    selectedSort = sort
                }) {
                    HStack {
                        Label(sort.rawValue, systemImage: sort.icon)
                        if selectedSort == sort {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }
}
