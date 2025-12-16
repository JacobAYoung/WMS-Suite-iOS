//
//  DataManagementView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showingExportOptions = false
    @State private var showingImportPicker = false
    @State private var showingImportConfirmation = false
    @State private var importedItemsCount = 0
    @State private var exportFormat: ExportFormat = .csv
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case iif = "IIF (QuickBooks)"
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .iif: return "iif"
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                Button(action: { showingExportOptions = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text("Export Inventory")
                            Text("Export as CSV or IIF format")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                
                Button(action: { showingImportPicker = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.green)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text("Import Inventory")
                            Text("Import from CSV file")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            } header: {
                Text("Import/Export")
            } footer: {
                Text("Export to CSV for general use or IIF format for QuickBooks Desktop. Import from CSV to bulk add items.")
            }
            
            Section {
                HStack {
                    Text("Total Items")
                    Spacer()
                    Text("\(viewModel.items.count)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Current Inventory")
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button(format.rawValue) {
                    exportFormat = format
                    exportData(format: format)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose export format")
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Complete", isPresented: $showingImportConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Successfully imported \(importedItemsCount) items")
        }
    }
    
    private func exportData(format: ExportFormat) {
        let exportString: String
        let fileName: String
        
        switch format {
        case .csv:
            exportString = ExportImportService.generateCSV(items: viewModel.items)
            fileName = "inventory_export.csv"
        case .iif:
            exportString = ExportImportService.generateIIF(items: viewModel.items)
            fileName = "inventory_export.iif"
        }
        
        shareFile(content: exportString, fileName: fileName)
    }
    
    private func shareFile(content: String, fileName: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                
                // For iPad: set popover presentation controller
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Error exporting file: \(error)")
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let csvString = try String(contentsOf: url, encoding: .utf8)
                let parsedItems = ExportImportService.parseCSV(csvString)
                
                // Import items
                Task {
                    var count = 0
                    for item in parsedItems {
                        viewModel.addItem(
                            sku: item.sku,
                            name: item.name,
                            description: item.description,
                            upc: item.upc,
                            webSKU: item.webSKU,
                            quantity: item.quantity,
                            minStockLevel: item.minStockLevel,
                            imageUrl: item.imageUrl
                        )
                        count += 1
                    }
                    
                    await MainActor.run {
                        importedItemsCount = count
                        showingImportConfirmation = true
                    }
                }
            } catch {
                print("Error importing CSV: \(error)")
            }
            
        case .failure(let error):
            print("Error selecting file: \(error)")
        }
    }
}
