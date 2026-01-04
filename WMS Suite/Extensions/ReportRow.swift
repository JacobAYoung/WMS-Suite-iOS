//
//  ReportRow.swift
//  WMS Suite
//
//  Updated to use ReportConfig system
//

import SwiftUI

struct ReportRow: View {
    let report: ReportConfig
    
    var body: some View {
        NavigationLink(destination: report.destination) {
            HStack(spacing: 16) {
                Image(systemName: report.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(report.color)
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(report.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}
