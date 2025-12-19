//
//  OrderDetailView.swift
//  WMS Suite
//
//  Enhanced: Added priority, notes, pick list, and fulfillment tracking
//

import SwiftUI
import CoreData

struct OrderDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let sale: Sale
    
    @State private var showingStatusMenu = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAddNote = false 
    
    var lineItemsArray: [SaleLineItem] {
        guard let items = sale.lineItems as? Set<SaleLineItem> else { return [] }
        return Array(items).sorted { ($0.item?.name ?? "") < ($1.item?.name ?? "") }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Priority/Attention Badges
                if sale.hasFlagsSet {
                    flagBadgesSection
                }
                
                // Order Header Card
                orderHeaderSection
                
                // Fulfillment Status & Tracking (if applicable)
                if sale.fulfillmentStatusEnum != nil {
                    fulfillmentSection
                }
                
                // Pick List (if needs fulfillment)
                if sale.needsFulfillment {
                    OrderPickListView(sale: sale)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                }
                
                // Line Items Section
                lineItemsSection
                
                // Notes & History
                OrderNotesView(sale: sale)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Priority toggle
                    Button(action: { togglePriority() }) {
                        Label(
                            sale.isPriority ? "Remove Priority" : "Mark as Priority",
                            systemImage: sale.isPriority ? "star.slash" : "star.fill"
                        )
                    }
                    
                    // Attention toggle
                    Button(action: { toggleAttention() }) {
                        Label(
                            sale.needsAttention ? "Remove Attention Flag" : "Needs Attention",
                            systemImage: sale.needsAttention ? "checkmark.circle" : "exclamationmark.triangle"
                        )
                    }
                    
                    Divider()
                    
                    // Status change menu (if local order)
                    if sale.orderSource == .local || sale.orderSource == nil {
                        Menu("Change Status") {
                            ForEach(OrderFulfillmentStatus.allCases) { status in
                                Button(action: { updateStatus(to: status) }) {
                                    Label(status.displayName, systemImage: status.icon)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Delete
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Order", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Order?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteOrder()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // MARK: - Flag Badges Section
    
    private var flagBadgesSection: some View {
        HStack(spacing: 12) {
            if sale.isPriority {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Priority")
                }
                .font(.subheadline)
                .bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
            
            if sale.needsAttention {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("Needs Attention")
                }
                .font(.subheadline)
                .bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.horizontal)
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
            
            // Fulfillment Status
            if let status = sale.fulfillmentStatusEnum {
                HStack {
                    Text("Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                        Text(status.displayName)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(status.color.opacity(0.2))
                    .foregroundColor(status.color)
                    .cornerRadius(8)
                }
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
    
    // MARK: - Fulfillment Section
    
    private var fulfillmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shipping & Tracking")
                .font(.headline)
            
            if let tracking = sale.trackingDisplayText {
                InfoRow(label: "Tracking", value: tracking)
            }
            
            if let shipped = sale.shippedDate {
                InfoRow(label: "Shipped", value: shipped.formatted(date: .abbreviated, time: .omitted))
                
                if let days = sale.daysSinceShipped {
                    InfoRow(label: "Days in Transit", value: "\(days)")
                }
            }
            
            if let delivered = sale.deliveredDate {
                InfoRow(label: "Delivered", value: delivered.formatted(date: .abbreviated, time: .omitted))
            } else if let estimated = sale.estimatedDeliveryDate {
                InfoRow(label: "Est. Delivery", value: estimated.formatted(date: .abbreviated, time: .omitted))
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
    
    // MARK: - Actions
    
    private func togglePriority() {
        let wasPriority = sale.isPriority
        sale.isPriority.toggle()
        
        // Add history note
        let noteType: OrderNoteType = sale.isPriority ? .prioritySet : .priorityRemoved
        sale.addNote(
            text: noteType.displayText,
            type: noteType.rawValue,
            userName: nil,
            context: viewContext
        )
        
        saveChanges()
    }
    
    private func toggleAttention() {
        let wasAttention = sale.needsAttention
        sale.needsAttention.toggle()
        
        // Add history note
        let noteType: OrderNoteType = sale.needsAttention ? .attentionSet : .attentionRemoved
        sale.addNote(
            text: noteType.displayText,
            type: noteType.rawValue,
            userName: nil,
            context: viewContext
        )
        
        saveChanges()
    }
    
    private func updateStatus(to status: OrderFulfillmentStatus) {
        let oldStatus = sale.fulfillmentStatusEnum?.displayName ?? "None"
        sale.setFulfillmentStatus(status)
        
        // Add history note
        sale.addNote(
            text: "Status changed from \(oldStatus) to \(status.displayName)",
            type: OrderNoteType.statusChanged.rawValue,
            userName: nil,
            context: viewContext
        )
        
        saveChanges()
    }
    
    private func deleteOrder() {
        viewContext.delete(sale)
        saveChanges()
    }
    
    private func saveChanges() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving changes: \(error)")
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

// MARK: - Info Row

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
