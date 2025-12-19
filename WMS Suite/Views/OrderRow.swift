//
//  OrderRow.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/18/25.
//

import SwiftUI

struct OrderRow: View {
    let sale: Sale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Order number or ID
                VStack(alignment: .leading, spacing: 4) {
                    if let orderNumber = sale.orderNumber, !orderNumber.isEmpty {
                        Text("Order \(orderNumber)")
                            .font(.headline)
                    } else {
                        Text("Sale #\(sale.id)")
                            .font(.headline)
                    }
                    
                    if let date = sale.saleDate {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Source badge
                if let source = sale.orderSource {
                    HStack(spacing: 4) {
                        Image(systemName: source.icon)
                        Text(source.displayName)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(source.color.opacity(0.2))
                    .foregroundColor(source.color)
                    .cornerRadius(8)
                }
            }
            
            // Stats row
            HStack(spacing: 16) {
                Label("\(sale.itemCount) items", systemImage: "shippingbox")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(sale.totalQuantity) units", systemImage: "number")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
