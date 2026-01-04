//
//  ReportsView.swift
//  WMS Suite
//
//  Central hub for all reports and analytics
//  Refactored: Data-driven configuration system
//

import SwiftUI

struct ReportsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Report Configuration
    
    /// All available reports (data-driven)
    private var availableReports: [ReportConfig] {
        ReportConfig.allReports(viewModel: viewModel)
    }
    
    /// Filter reports by category
    private func reports(for category: ReportCategory) -> [ReportConfig] {
        availableReports.filter { $0.category == category }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad layout - Full screen grid
                reportGrid
                    .navigationTitle("Reports & Analytics")
            } else {
                // iPhone layout - Categorized list
                reportList
            }
        }
    }
    
    // MARK: - Report Grid (iPad)
    
    private var reportGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: isIPad ? 350 : 300, maximum: isIPad ? 500 : 400), spacing: 20)
            ], spacing: 20) {
                ForEach(availableReports) { report in
                    ReportTile(report: report)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Report List (iPhone)
    
    private var reportList: some View {
        List {
            ForEach(ReportCategory.allCases) { category in
                Section(header: Text(category.title)) {
                    ForEach(reports(for: category)) { report in
                        ReportRow(report: report)
                    }
                }
            }
        }
        .navigationTitle("Reports")
    }
    
    // MARK: - Helpers
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

// MARK: - Report Tile Component

struct ReportTile: View {
    let report: ReportConfig
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationLink(destination: report.destination) {
            VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
                HStack {
                    Image(systemName: report.icon)
                        .font(.system(size: isIPad ? 50 : 40))
                        .foregroundColor(report.color)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(isIPad ? .body : .caption)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.title)
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(report.description)
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(isIPad ? 24 : 20)
            .frame(minHeight: isIPad ? 220 : 180)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(isIPad ? 20 : 16)
            .shadow(color: Color.black.opacity(0.08), radius: isIPad ? 12 : 8, x: 0, y: isIPad ? 4 : 2)
        }
        .buttonStyle(.plain)
    }
}



