//
//  DuplicateDetectionReportView.swift
//  WMS Suite
//
//  Report view for detecting duplicate SKUs, UPCs, and other data quality issues
//

import SwiftUI

struct DuplicateDetectionReportView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var issues: [DuplicateIssue] = []
    @State private var isLoading = true
    @State private var selectedIssue: DuplicateIssue?
    @State private var showingIssueDetail = false
    @State private var filterType: DuplicateIssueType?
    
    var filteredIssues: [DuplicateIssue] {
        if let filterType = filterType {
            return issues.filter { $0.type == filterType }
        }
        return issues
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if issues.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle("Product Health Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: analyzeInventory) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            analyzeInventory()
        }
        .sheet(isPresented: $showingIssueDetail) {
            if let issue = selectedIssue {
                DuplicateIssueDetailView(issue: issue, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Analyzing inventory...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("No Issues Found")
                .font(.title2)
                .bold()
            
            Text("Your inventory data looks clean! No duplicate SKUs, UPCs, or other data quality issues detected.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var contentView: some View {
        List {
            // Summary Section
            Section {
                summaryCard
            }
            
            // Filter Section
            Section {
                filterPicker
            }
            
            // Issues List
            Section {
                ForEach(filteredIssues) { issue in
                    IssueRow(issue: issue)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedIssue = issue
                            showingIssueDetail = true
                        }
                }
            } header: {
                Text("\(filteredIssues.count) Issue\(filteredIssues.count == 1 ? "" : "s") Found")
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(issues.count)")
                        .font(.title)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Items Affected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(affectedItemsCount)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            // Breakdown by type
            VStack(spacing: 8) {
                ForEach(DuplicateIssueType.allCases, id: \.self) { type in
                    let count = issues.filter { $0.type == type }.count
                    if count > 0 {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                                .frame(width: 20)
                            Text(type.rawValue)
                                .font(.subheadline)
                            Spacer()
                            Text("\(count)")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(type.color)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    count: issues.count,
                    isSelected: filterType == nil,
                    color: .blue
                ) {
                    filterType = nil
                }
                
                ForEach(DuplicateIssueType.allCases, id: \.self) { type in
                    let count = issues.filter { $0.type == type }.count
                    if count > 0 {
                        FilterChip(
                            title: type.rawValue,
                            count: count,
                            isSelected: filterType == type,
                            color: type.color
                        ) {
                            filterType = type
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var affectedItemsCount: Int {
        let allItems = issues.flatMap { $0.items }
        let uniqueItems = Set(allItems.map { $0.objectID })
        return uniqueItems.count
    }
    
    // MARK: - Actions
    
    private func analyzeInventory() {
        isLoading = true
        
        // Simulate async work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            issues = DuplicateDetectionService.analyzeInventory(viewModel.items)
            isLoading = false
        }
    }
}

// MARK: - Issue Row Component

struct IssueRow: View {
    let issue: DuplicateIssue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: issue.type.icon)
                    .foregroundColor(issue.type.color)
                    .frame(width: 24)
                
                Text(issue.type.rawValue)
                    .font(.headline)
                
                Spacer()
                
                Text(issue.severityText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(issue.type.color.opacity(0.2))
                    .foregroundColor(issue.type.color)
                    .cornerRadius(8)
            }
            
            Text(issue.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("\(issue.items.count) items affected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(uiColor: .secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Issue Detail View

struct DuplicateIssueDetailView: View {
    let issue: DuplicateIssue
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: issue.type.icon)
                                .font(.title2)
                                .foregroundColor(issue.type.color)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.type.rawValue)
                                    .font(.headline)
                                Text("Severity: \(issue.severityText)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Issue")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text(issue.description)
                                .font(.body)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommendation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text(issue.recommendation)
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    ForEach(issue.items, id: \.objectID) { item in
                        NavigationLink(destination: ProductDetailView(viewModel: viewModel, item: item)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Unknown Item")
                                    .font(.headline)
                                
                                if let sku = item.sku {
                                    Text("SKU: \(sku)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 8) {
                                    ForEach(item.itemSources, id: \.self) { source in
                                        HStack(spacing: 4) {
                                            Image(systemName: source.iconName)
                                            Text(source.rawValue)
                                        }
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(source.color.opacity(0.2))
                                        .foregroundColor(source.color)
                                        .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Affected Items (\(issue.items.count))")
                }
            }
            .navigationTitle("Issue Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

