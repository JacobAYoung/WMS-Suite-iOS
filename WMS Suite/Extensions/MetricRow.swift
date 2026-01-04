//
//  MetricRow.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/29/24.
//

import SwiftUI

struct MetricRow: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(valueColor)
        }
    }
}
