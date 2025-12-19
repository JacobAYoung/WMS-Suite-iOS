//
//  OrderDetailView.swift
//  WMS Suite
//
//  Detailed view of a single order with all line items
//

import SwiftUI
import CoreData

struct OrderDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let sale: Sale
    
    var lineItemsArray: [SaleLineItem] {
        guard let items = sale.lineItems as? Set<SaleLineItem> else { return [] }
        return Array(items).sorted { ($0.item?.name ?? "") < ($1.item?.name ?? "") }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Order Header Card
                orderHeaderSection
                
                // Line Items Section
                lineItemsSection
            }
            .padding()
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Section
    
    private var orderHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Information")
                .font(.headline)
            
            // Order number
            if let orderNumber = sale.orderNumber, !orderNumber.isEmpty {
                InfoRow(label: "Order Number", value: orderNumber)
            } else {
                InfoRow(label: "Sale ID", value: "#\(sale.id)")
            }
            
            // Date
            if let date = sale.saleDate {
                InfoRow(label: "Date", value: date.formatted(date: .long, time: .shortened))
            }
            
            // Source
            if let source = sale.orderSource {
                HStack {
                    Text("Source")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: source.icon)
                        Text(source.displayName)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(source.color.opacity(0.2))
                    .foregroundColor(source.color)
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Totals
            InfoRow(label: "Total Items", value: "\(sale.itemCount)")
            InfoRow(label: "Total Quantity", value: "\(sale.totalQuantity) units")
            
            if let totalAmount = sale.totalAmount as? Decimal, totalAmount > 0 {
                InfoRow(label: "Total Amount", value: "$\(totalAmount)")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Line Items Section
    
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items in This Order")
                .font(.headline)
                .padding(.horizontal)
            
            if lineItemsArray.isEmpty {
                Text("No items in this order")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(lineItemsArray, id: \.id) { lineItem in
                        if let item = lineItem.item {
                            NavigationLink(destination: ProductDetailView(viewModel: createViewModel(), item: item)) {
                                LineItemCard(lineItem: lineItem)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper
    
    private func createViewModel() -> InventoryViewModel {
        let context = PersistenceController.shared.container.viewContext
        let repo = InventoryRepository(context: context)
        let shopifyService = ShopifyService(
            storeUrl: UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? "",
            accessToken: UserDefaults.standard.string(forKey: "shopifyAccessToken") ?? ""
        )
        let quickbooksService = QuickBooksService(
            companyId: UserDefaults.standard.string(forKey: "quickbooksCompanyId") ?? "",
            accessToken: UserDefaults.standard.string(forKey: "quickbooksAccessToken") ?? "",
            refreshToken: UserDefaults.standard.string(forKey: "quickbooksRefreshToken") ?? ""
        )
        let barcodeService = BarcodeService()
        
        return InventoryViewModel(
            repository: repo,
            shopifyService: shopifyService,
            quickbooksService: quickbooksService,
            barcodeService: barcodeService
        )
    }
}

// MARK: - Line Item Card

struct LineItemCard: View {
    let lineItem: SaleLineItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(lineItem.item?.name ?? "Unknown Item")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let sku = lineItem.item?.sku {
                    Text("SKU: \(sku)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let unitPrice = lineItem.unitPrice as Decimal?, unitPrice > 0 {
                    Text("$\(unitPrice) each")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("×\(lineItem.quantity)")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.blue)
                
                if let lineTotal = lineItem.lineTotal as Decimal?, lineTotal > 0 {
                    Text("$\(lineTotal)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Info Row (reuse from ProductDetailView)

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .bold()
        }
    }
}
