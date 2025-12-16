//
//  ExportImportService.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import Foundation

class ExportImportService {
    
    // MARK: - CSV Export (Enhanced)
    static func generateCSV(items: [InventoryItem]) -> String {
        var csv = "SKU,Name,Description,UPC,WebSKU,Quantity,MinStockLevel,ShopifyID,QuickBooksID,ImageURL,LastUpdated\n"
        
        for item in items {
            let sku = escapeCSV(item.sku ?? "")
            let name = escapeCSV(item.name ?? "")
            let desc = escapeCSV(item.itemDescription ?? "")
            let upc = escapeCSV(item.upc ?? "")
            let webSKU = escapeCSV(item.webSKU ?? "")
            let qty = "\(item.quantity)"
            let minStock = "\(item.minStockLevel)"
            let shopifyId = escapeCSV(item.shopifyProductId ?? "")
            let qbId = escapeCSV(item.quickbooksItemId ?? "")
            let imageUrl = escapeCSV(item.imageUrl ?? "")
            let updated = item.lastUpdated?.ISO8601Format() ?? ""
            
            csv += "\(sku),\(name),\(desc),\(upc),\(webSKU),\(qty),\(minStock),\(shopifyId),\(qbId),\(imageUrl),\(updated)\n"
        }
        
        return csv
    }
    
    // MARK: - IIF Export (QuickBooks Desktop)
    static func generateIIF(items: [InventoryItem]) -> String {
        var iif = "!INVITEM\tNAME\tDESC\tPRICE\tCOST\tQTYONHAND\n"
        
        for item in items {
            let name = (item.sku ?? "ITEM").replacingOccurrences(of: "\t", with: " ")
            let desc = (item.name ?? "").replacingOccurrences(of: "\t", with: " ")
            let price = "0.00" // Default price, can be enhanced
            let cost = "0.00" // Default cost, can be enhanced
            let qty = "\(item.quantity)"
            
            iif += "INVITEM\t\(name)\t\(desc)\t\(price)\t\(cost)\t\(qty)\n"
        }
        
        return iif
    }
    
    // MARK: - CSV Import
    static func parseCSV(_ csvString: String) -> [(sku: String, name: String, description: String?, upc: String?, webSKU: String?, quantity: Int32, minStockLevel: Int32, imageUrl: String?)] {
        var items: [(sku: String, name: String, description: String?, upc: String?, webSKU: String?, quantity: Int32, minStockLevel: Int32, imageUrl: String?)] = []
        
        let lines = csvString.components(separatedBy: .newlines)
        
        // Skip header row
        guard lines.count > 1 else { return items }
        
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            let columns = parseCSVLine(line)
            
            // Expected format: SKU,Name,Description,UPC,WebSKU,Quantity,MinStockLevel,ShopifyID,QuickBooksID,ImageURL,LastUpdated
            guard columns.count >= 7 else { continue }
            
            let sku = columns[0]
            let name = columns[1]
            let description = columns.count > 2 && !columns[2].isEmpty ? columns[2] : nil
            let upc = columns.count > 3 && !columns[3].isEmpty ? columns[3] : nil
            let webSKU = columns.count > 4 && !columns[4].isEmpty ? columns[4] : nil
            let quantity = Int32(columns[5]) ?? 0
            let minStockLevel = Int32(columns[6]) ?? 0
            let imageUrl = columns.count > 9 && !columns[9].isEmpty ? columns[9] : nil
            
            items.append((sku: sku, name: name, description: description, upc: upc, webSKU: webSKU, quantity: quantity, minStockLevel: minStockLevel, imageUrl: imageUrl))
        }
        
        return items
    }
    
    // MARK: - Helper Functions
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn.replacingOccurrences(of: "\"\"", with: "\""))
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        
        columns.append(currentColumn.replacingOccurrences(of: "\"\"", with: "\""))
        return columns
    }
}
