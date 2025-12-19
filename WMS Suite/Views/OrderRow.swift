//
//  OrderRow.swift
//  WMS Suite
//
//  Enhanced: Added priority badges, fulfillment status, and tracking info
//

import SwiftUI

struct OrderRow: View {
    let sale: Sale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Priority/Attention badges (if set)
            if sale.hasFlagsSet {
                HStack(spacing: 8) {
                    if sale.isPriority {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Priority")
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                    }
                    
                    if sale.needsAttention {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text("Attention")
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                    }
                }
            }
            
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
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Fulfillment status badge (if set)
                    if let status = sale.fulfillmentStatusEnum {
                        HStack(spacing: 4) {
                            Image(systemName: status.icon)
                            Text(status.displayName)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status.color.opacity(0.2))
                        .foregroundColor(status.color)
                        .cornerRadius(8)
                    }
                    
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
            }
            
            // Stats row
            HStack(spacing: 16) {
                Label("\(sale.itemCount) items", systemImage: "shippingbox")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(sale.totalQuantity) units", systemImage: "number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Show tracking info if available
                if let tracking = sale.trackingNumber, !tracking.isEmpty {
                    Label("Tracking", systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
