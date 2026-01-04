//
//  ReportConfig.swift
//  WMS Suite
//
//  Report configuration system for data-driven report management
//

import SwiftUI

// MARK: - Report Category

enum ReportCategory: String, CaseIterable, Identifiable {
    case inventory = "Inventory Reports"
    case dataQuality = "Data Quality"
    case planning = "Planning & Forecasting"
    case financial = "Financial Analysis"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
}

// MARK: - Report Configuration

struct ReportConfig: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
    let category: ReportCategory
    let destination: AnyView
    
    // MARK: - Static Factory Methods
    
    /// Inventory Value Report
    static func inventoryValue(viewModel: InventoryViewModel) -> ReportConfig {
        ReportConfig(
            icon: "chart.bar.fill",
            title: "Inventory Value",
            description: "Total value of your inventory",
            color: .blue,
            category: .inventory,
            destination: AnyView(InventoryValueReportView(viewModel: viewModel))
        )
    }
    
    /// Product Health Check Report
    static func productHealth(viewModel: InventoryViewModel) -> ReportConfig {
        ReportConfig(
            icon: "checkmark.seal.fill",
            title: "Product Health Check",
            description: "Detect duplicate SKUs, UPCs, and data quality issues",
            color: .purple,
            category: .dataQuality,
            destination: AnyView(DuplicateDetectionReportView(viewModel: viewModel))
        )
    }
    
    /// Reorder Recommendations Report
    static func reorderRecommendations(viewModel: InventoryViewModel) -> ReportConfig {
        ReportConfig(
            icon: "arrow.triangle.2.circlepath",
            title: "Reorder Recommendations",
            description: "Smart restocking suggestions based on sales velocity",
            color: .orange,
            category: .planning,
            destination: AnyView(ReorderRecommendationsReportView(viewModel: viewModel))
        )
    }
    
    /// Profit Margins Report
    static func profitMargins(viewModel: InventoryViewModel) -> ReportConfig {
        ReportConfig(
            icon: "dollarsign.circle.fill",
            title: "Profit Margins",
            description: "Analyze profitability and calculate margins",
            color: .green,
            category: .financial,
            destination: AnyView(ProfitMarginReportView(viewModel: viewModel))
        )
    }
}

// MARK: - Report Configuration Provider

extension ReportConfig {
    /// Get all available reports for a view model
    static func allReports(viewModel: InventoryViewModel) -> [ReportConfig] {
        [
            .inventoryValue(viewModel: viewModel),
            .productHealth(viewModel: viewModel),
            .reorderRecommendations(viewModel: viewModel),
            .profitMargins(viewModel: viewModel)
        ]
    }
    
    /// Get reports filtered by category
    static func reports(for category: ReportCategory, viewModel: InventoryViewModel) -> [ReportConfig] {
        allReports(viewModel: viewModel).filter { $0.category == category }
    }
}
