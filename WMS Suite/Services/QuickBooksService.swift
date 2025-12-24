//
//  QuickBooksService.swift
//  WMS Suite
//
//  Complete QuickBooks Online implementation with customer & invoice sync
//

import Foundation
import CoreData

class QuickBooksService: QuickBooksServiceProtocol {
    private var companyId: String
    private var accessToken: String
    private var refreshToken: String
    
    // Account references (configured by user)
    private var incomeAccountId: String
    private var cogsAccountId: String
    private var assetAccountId: String
    
    // QBO API endpoint (production)
    private let baseURL = "https://quickbooks.api.intuit.com/v3/company"
    
    init(companyId: String, accessToken: String, refreshToken: String) {
        self.companyId = companyId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        
        // Load account IDs from UserDefaults
        self.incomeAccountId = UserDefaults.standard.string(forKey: "quickbooksIncomeAccountId") ?? ""
        self.cogsAccountId = UserDefaults.standard.string(forKey: "quickbooksCOGSAccountId") ?? ""
        self.assetAccountId = UserDefaults.standard.string(forKey: "quickbooksAssetAccountId") ?? ""
    }
    
    func updateCredentials(companyId: String, accessToken: String, refreshToken: String) {
        self.companyId = companyId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    
    // MARK: - AUTO-REFRESH AUTHENTICATED REQUEST
    
    /// Make an authenticated request with automatic token refresh on 401
    private func makeAuthenticatedRequest(_ request: URLRequest, maxRetries: Int = 1) async throws -> (Data, HTTPURLResponse) {
        var modifiedRequest = request
        
        // Check if we should preemptively refresh the token
        if QuickBooksTokenManager.shared.shouldRefreshToken() {
            print("⏰ QuickBooks token expiring soon, refreshing proactively...")
            do {
                let (newAccessToken, _) = try await QuickBooksTokenManager.shared.refreshAccessToken()
                self.accessToken = newAccessToken
            } catch {
                print("⚠️ Proactive token refresh failed: \(error)")
                // Continue with current token, will retry on 401
            }
        }
        
        modifiedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: modifiedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuickBooksError.invalidResponse
        }
        
        // Check for 401 Unauthorized (expired token)
        if httpResponse.statusCode == 401 && maxRetries > 0 {
            print("⚠️ QuickBooks token expired, refreshing...")
            
            do {
                // Refresh the token
                let (newAccessToken, _) = try await QuickBooksTokenManager.shared.refreshAccessToken()
                
                // Update our local token
                self.accessToken = newAccessToken
                
                // Retry the request with new token
                print("🔄 Retrying request with new token...")
                return try await makeAuthenticatedRequest(request, maxRetries: maxRetries - 1)
                
            } catch {
                print("❌ Token refresh failed: \(error)")
                throw error
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fault = errorJson["Fault"] as? [String: Any],
               let errors = fault["Error"] as? [[String: Any]],
               let message = errors.first?["Message"] as? String {
                print("QBO Error: \(message)")
            }
            throw QuickBooksError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return (data, httpResponse)
    }
    
    // MARK: - ✅ CUSTOMER SYNC (WITH PAGINATION)
    
    /// Sync customers from QuickBooks with pagination support
    func syncCustomers(context: NSManagedObjectContext, logMessage: @escaping (String) -> Void) async throws {
        guard !accessToken.isEmpty && !companyId.isEmpty else {
            throw QuickBooksError.missingCredentials
        }
        
        print("🔄 Starting paginated customer sync from QuickBooks...")
        logMessage("Starting customer sync from QuickBooks...")
        
        var allCustomers: [[String: Any]] = []
        var currentPosition = 1
        let pageSize = 100
        var hasMorePages = true
        var pageCount = 0
        
        while hasMorePages {
            pageCount += 1
            print("📄 Fetching customer page \(pageCount) (position \(currentPosition))...")
            logMessage("Fetching customer page \(pageCount)...")
            
            do {
                let (customers, _) = try await fetchCustomersPage(startPosition: currentPosition, maxResults: pageSize)
                allCustomers.append(contentsOf: customers)
                
                if customers.count < pageSize {
                    hasMorePages = false
                } else {
                    currentPosition += customers.count
                }
                
                if pageCount > 100 {
                    print("⚠️ Reached safety limit of 100 pages")
                    logMessage("⚠️ Safety limit reached - synced first 10,000 customers")
                    break
                }
            } catch {
                print("❌ Error fetching customer page \(pageCount): \(error)")
                throw error
            }
        }
        
        print("✅ Fetched \(allCustomers.count) customers across \(pageCount) pages")
        logMessage("Fetched \(allCustomers.count) customers from QuickBooks")
        
        var createdCount = 0
        var updatedCount = 0
        
        for (index, customerData) in allCustomers.enumerated() {
            do {
                let result = try await processCustomer(customerData, context: context)
                if result.created {
                    createdCount += 1
                } else if result.updated {
                    updatedCount += 1
                }
                
                if (index + 1) % 50 == 0 {
                    logMessage("Processed \(index + 1)/\(allCustomers.count) customers...")
                }
            } catch {
                print("❌ Error processing customer: \(error)")
            }
        }
        
        logMessage("✅ Created \(createdCount) new, updated \(updatedCount) existing customers")
        print("✅ QuickBooks customer sync completed")
    }
    
    private func fetchCustomersPage(startPosition: Int, maxResults: Int) async throws -> (customers: [[String: Any]], maxResults: Int) {
        let query = "SELECT * FROM Customer WHERE Active = true STARTPOSITION \(startPosition) MAXRESULTS \(maxResults)"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let url = URL(string: "\(baseURL)/\(companyId)/query?query=\(encodedQuery)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryResponse = json["QueryResponse"] as? [String: Any] else {
            throw QuickBooksError.parseError
        }
        
        let customers = queryResponse["Customer"] as? [[String: Any]] ?? []
        let maxResults = queryResponse["maxResults"] as? Int ?? maxResults
        
        return (customers, maxResults)
    }
    
    private func processCustomer(_ customerData: [String: Any], context: NSManagedObjectContext) async throws -> (created: Bool, updated: Bool) {
        return try await context.perform {
            guard let qbCustomerId = customerData["Id"] as? String else {
                return (false, false)
            }
            
            let displayName = customerData["DisplayName"] as? String ?? "Unknown Customer"
            let companyName = customerData["CompanyName"] as? String
            let givenName = customerData["GivenName"] as? String
            let familyName = customerData["FamilyName"] as? String
            
            let fullName: String
            if let given = givenName, let family = familyName {
                fullName = "\(given) \(family)"
            } else {
                fullName = displayName
            }
            
            let primaryEmailAddr = customerData["PrimaryEmailAddr"] as? [String: Any]
            let email = primaryEmailAddr?["Address"] as? String
            
            let primaryPhone = customerData["PrimaryPhone"] as? [String: Any]
            let phone = primaryPhone?["FreeFormNumber"] as? String
            
            var billingAddress: String?
            var shippingAddress: String?
            
            if let billAddr = customerData["BillAddr"] as? [String: Any] {
                billingAddress = self.formatAddress(billAddr)
            }
            
            if let shipAddr = customerData["ShipAddr"] as? [String: Any] {
                shippingAddress = self.formatAddress(shipAddr)
            }
            
            let balanceValue = customerData["Balance"] as? Double ?? 0.0
            let balance = NSDecimalNumber(value: balanceValue)
            
            let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
            fetchRequest.predicate = NSPredicate(format: "quickbooksCustomerId == %@", qbCustomerId)
            fetchRequest.fetchLimit = 1
            
            let existingCustomers = try context.fetch(fetchRequest)
            
            let customer: Customer
            let isNew: Bool
            
            if let existingCustomer = existingCustomers.first {
                customer = existingCustomer
                isNew = false
            } else {
                customer = Customer(context: context)
                customer.id = Int32(Date().timeIntervalSince1970)
                customer.createdDate = Date()
                isNew = true
            }
            
            customer.quickbooksCustomerId = qbCustomerId
            customer.name = fullName
            customer.companyName = companyName
            customer.email = email
            customer.phone = phone
            customer.billingAddress = billingAddress
            customer.shippingAddress = shippingAddress
            customer.address = billingAddress ?? shippingAddress
            customer.balance = balance
            customer.lastSyncedQuickbooksDate = Date()
            
            try context.save()
            
            return (isNew, !isNew)
        }
    }
    
    private func formatAddress(_ addressDict: [String: Any]) -> String {
        var components: [String] = []
        
        if let line1 = addressDict["Line1"] as? String, !line1.isEmpty {
            components.append(line1)
        }
        if let line2 = addressDict["Line2"] as? String, !line2.isEmpty {
            components.append(line2)
        }
        if let city = addressDict["City"] as? String, !city.isEmpty {
            components.append(city)
        }
        if let state = addressDict["CountrySubDivisionCode"] as? String, !state.isEmpty {
            components.append(state)
        }
        if let postalCode = addressDict["PostalCode"] as? String, !postalCode.isEmpty {
            components.append(postalCode)
        }
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - ✅ INVOICE SYNC (WITH PAGINATION)
    
    /// Sync invoices from QuickBooks with pagination support
    func syncInvoices(context: NSManagedObjectContext, logMessage: @escaping (String) -> Void) async throws {
        guard !accessToken.isEmpty && !companyId.isEmpty else {
            throw QuickBooksError.missingCredentials
        }
        
        print("🔄 Starting paginated invoice sync from QuickBooks...")
        logMessage("Starting invoice sync from QuickBooks...")
        
        var allInvoices: [[String: Any]] = []
        var currentPosition = 1
        let pageSize = 100
        var hasMorePages = true
        var pageCount = 0
        
        while hasMorePages {
            pageCount += 1
            print("📄 Fetching invoice page \(pageCount) (position \(currentPosition))...")
            logMessage("Fetching invoice page \(pageCount)...")
            
            do {
                let (invoices, _) = try await fetchInvoicesPage(startPosition: currentPosition, maxResults: pageSize)
                allInvoices.append(contentsOf: invoices)
                
                if invoices.count < pageSize {
                    hasMorePages = false
                } else {
                    currentPosition += invoices.count
                }
                
                if pageCount > 100 {
                    print("⚠️ Reached safety limit of 100 pages")
                    logMessage("⚠️ Safety limit reached - synced first 10,000 invoices")
                    break
                }
            } catch {
                print("❌ Error fetching invoice page \(pageCount): \(error)")
                throw error
            }
        }
        
        print("✅ Fetched \(allInvoices.count) invoices across \(pageCount) pages")
        logMessage("Fetched \(allInvoices.count) invoices from QuickBooks")
        
        var createdCount = 0
        var updatedCount = 0
        
        for (index, invoiceData) in allInvoices.enumerated() {
            do {
                let result = try await processInvoice(invoiceData, context: context)
                if result.created {
                    createdCount += 1
                } else if result.updated {
                    updatedCount += 1
                }
                
                if (index + 1) % 50 == 0 {
                    logMessage("Processed \(index + 1)/\(allInvoices.count) invoices...")
                }
            } catch {
                print("❌ Error processing invoice: \(error)")
            }
        }
        
        logMessage("✅ Created \(createdCount) new, updated \(updatedCount) existing invoices")
        print("✅ QuickBooks invoice sync completed")
    }
    
    private func fetchInvoicesPage(startPosition: Int, maxResults: Int) async throws -> (invoices: [[String: Any]], maxResults: Int) {
        let query = "SELECT * FROM Invoice STARTPOSITION \(startPosition) MAXRESULTS \(maxResults)"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let url = URL(string: "\(baseURL)/\(companyId)/query?query=\(encodedQuery)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryResponse = json["QueryResponse"] as? [String: Any] else {
            throw QuickBooksError.parseError
        }
        
        let invoices = queryResponse["Invoice"] as? [[String: Any]] ?? []
        let maxResults = queryResponse["maxResults"] as? Int ?? maxResults
        
        return (invoices, maxResults)
    }
    
    private func processInvoice(_ invoiceData: [String: Any], context: NSManagedObjectContext) async throws -> (created: Bool, updated: Bool) {
        return try await context.perform {
            guard let qbInvoiceId = invoiceData["Id"] as? String else {
                return (false, false)
            }
            
            let docNumber = invoiceData["DocNumber"] as? String ?? qbInvoiceId
            
            let txnDateString = invoiceData["TxnDate"] as? String
            let dueDateString = invoiceData["DueDate"] as? String
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let invoiceDate = txnDateString.flatMap { dateFormatter.date(from: $0) } ?? Date()
            let dueDate = dueDateString.flatMap { dateFormatter.date(from: $0) }
            
            let totalValue = invoiceData["TotalAmt"] as? Double ?? 0.0
            let balanceValue = invoiceData["Balance"] as? Double ?? 0.0
            
            var taxValue: Double = 0.0
            if let txnTaxDetail = invoiceData["TxnTaxDetail"] as? [String: Any],
               let totalTax = txnTaxDetail["TotalTax"] as? Double {
                taxValue = totalTax
            }
            
            let actualSubtotal = totalValue - taxValue
            let amountPaidValue = totalValue - balanceValue
            
            let customerRef = invoiceData["CustomerRef"] as? [String: Any]
            let customerId = customerRef?["value"] as? String
            
            let salesTermRef = invoiceData["SalesTermRef"] as? [String: Any]
            let terms = salesTermRef?["name"] as? String
            
            let memo = invoiceData["PrivateNote"] as? String
            let syncToken = invoiceData["SyncToken"] as? String
            
            let existingSale = Sale.fetchByQuickBooksId(qbInvoiceId, context: context)
            
            let sale: Sale
            let isNew: Bool
            
            if let existing = existingSale {
                sale = existing
                isNew = false
            } else {
                sale = Sale(context: context)
                sale.id = Int32(Date().timeIntervalSince1970)
                isNew = true
            }
            
            sale.updateFromQuickBooksInvoice(
                qbInvoiceId: qbInvoiceId,
                invoiceNumber: docNumber,
                date: invoiceDate,
                subtotal: NSDecimalNumber(value: actualSubtotal),
                taxAmount: NSDecimalNumber(value: taxValue),
                totalAmount: NSDecimalNumber(value: totalValue),
                amountPaid: NSDecimalNumber(value: amountPaidValue),
                dueDate: dueDate,
                terms: terms,
                memo: memo,
                syncToken: syncToken
            )
            
            if let customerId = customerId {
                let customerFetch = NSFetchRequest<Customer>(entityName: "Customer")
                customerFetch.predicate = NSPredicate(format: "quickbooksCustomerId == %@", customerId)
                customerFetch.fetchLimit = 1
                
                if let customer = try? context.fetch(customerFetch).first {
                    sale.customer = customer
                }
            }
            
            if let lineItems = invoiceData["Line"] as? [[String: Any]] {
                try self.processInvoiceLineItems(lineItems, for: sale, context: context)
            }
            
            try context.save()
            
            return (isNew, !isNew)
        }
    }
    
    private func processInvoiceLineItems(_ lineItemsData: [[String: Any]], for sale: Sale, context: NSManagedObjectContext) throws {
        if let existingItems = sale.lineItems as? Set<SaleLineItem> {
            existingItems.forEach { context.delete($0) }
        }
        
        for (index, lineData) in lineItemsData.enumerated() {
            guard let detailType = lineData["DetailType"] as? String,
                  detailType == "SalesItemLineDetail",
                  let salesDetail = lineData["SalesItemLineDetail"] as? [String: Any] else {
                continue
            }
            
            let lineItem = SaleLineItem(context: context)
            lineItem.id = Int32(Date().timeIntervalSince1970) + Int32(index)
            
            let quantity = lineData["Qty"] as? Double ?? 1.0
            let unitPrice = salesDetail["UnitPrice"] as? Double ?? 0.0
            let lineTotal = lineData["Amount"] as? Double ?? 0.0
            
            lineItem.quantity = Int32(quantity)
            lineItem.unitPrice = NSDecimalNumber(value: unitPrice)
            lineItem.lineTotal = NSDecimalNumber(value: lineTotal)
            
            if let itemRef = salesDetail["ItemRef"] as? [String: Any],
               let itemName = itemRef["name"] as? String {
                
                let itemFetch = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
                itemFetch.predicate = NSPredicate(format: "sku == %@ OR name == %@", itemName, itemName)
                itemFetch.fetchLimit = 1
                
                if let inventoryItem = try? context.fetch(itemFetch).first {
                    lineItem.item = inventoryItem
                }
            }
            
            lineItem.sale = sale
        }
    }
    
    /// Sync single invoice by ID
    func syncInvoice(qbInvoiceId: String, context: NSManagedObjectContext) async throws {
        let url = URL(string: "\(baseURL)/\(companyId)/invoice/\(qbInvoiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let invoice = json["Invoice"] as? [String: Any] else {
            throw QuickBooksError.parseError
        }
        
        _ = try await processInvoice(invoice, context: context)
        print("✅ Synced invoice: \(qbInvoiceId)")
    }
    
    // MARK: - ITEM SYNC (EXISTING)
    
    func pushItem(_ item: InventoryItem) async throws -> String {
        guard !accessToken.isEmpty && !companyId.isEmpty else {
            throw QuickBooksError.missingCredentials
        }
        
        guard !incomeAccountId.isEmpty && !cogsAccountId.isEmpty && !assetAccountId.isEmpty else {
            throw QuickBooksError.missingAccountConfiguration
        }
        
        if let qbItemId = item.quickbooksItemId, !qbItemId.isEmpty {
            try await updateQBOItem(item, qboItemId: qbItemId)
            return qbItemId
        } else {
            return try await createQBOItem(item)
        }
    }
    
    private func createQBOItem(_ item: InventoryItem) async throws -> String {
        let url = URL(string: "\(baseURL)/\(companyId)/item")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let itemData: [String: Any] = [
            "Name": item.name ?? item.sku ?? "Unknown Item",
            "Sku": item.sku ?? "",
            "Description": item.itemDescription ?? "",
            "Type": "Inventory",
            "TrackQtyOnHand": true,
            "QtyOnHand": Int(item.quantity),
            "InvStartDate": ISO8601DateFormatter().string(from: Date()),
            "IncomeAccountRef": ["value": incomeAccountId],
            "ExpenseAccountRef": ["value": cogsAccountId],
            "AssetAccountRef": ["value": assetAccountId]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: itemData, options: [])
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let itemResponse = json["Item"] as? [String: Any],
              let itemId = itemResponse["Id"] as? String else {
            throw QuickBooksError.parseError
        }
        
        print("✅ Created QBO Item with ID: \(itemId)")
        return itemId
    }
    
    private func updateQBOItem(_ item: InventoryItem, qboItemId: String) async throws {
        let currentItem = try await fetchQBOItem(itemId: qboItemId)
        
        guard let syncToken = currentItem["SyncToken"] as? String else {
            throw QuickBooksError.missingSyncToken
        }
        
        let url = URL(string: "\(baseURL)/\(companyId)/item")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let itemData: [String: Any] = [
            "Id": qboItemId,
            "SyncToken": syncToken,
            "Name": item.name ?? item.sku ?? "Unknown Item",
            "Sku": item.sku ?? "",
            "Description": item.itemDescription ?? "",
            "QtyOnHand": Int(item.quantity),
            "sparse": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: itemData, options: [])
        
        let (_, _) = try await makeAuthenticatedRequest(request)
        
        print("✅ Updated QBO Item: \(qboItemId)")
    }
    
    private func fetchQBOItem(itemId: String) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/\(companyId)/item/\(itemId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = json["Item"] as? [String: Any] else {
            throw QuickBooksError.parseError
        }
        
        return item
    }
    
    func syncInventory() async throws -> [InventoryItem] {
        guard !accessToken.isEmpty && !companyId.isEmpty else {
            throw QuickBooksError.missingCredentials
        }
        
        let query = "SELECT * FROM Item WHERE Type = 'Inventory'"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let url = URL(string: "\(baseURL)/\(companyId)/query?query=\(encodedQuery)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryResponse = json["QueryResponse"] as? [String: Any],
              let items = queryResponse["Item"] as? [[String: Any]] else {
            throw QuickBooksError.parseError
        }
        
        print("📦 Fetched \(items.count) items from QuickBooks Online")
        return []
    }
    
    func fetchAccounts() async throws -> [QBAccount] {
        let query = "SELECT * FROM Account"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let url = URL(string: "\(baseURL)/\(companyId)/query?query=\(encodedQuery)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await makeAuthenticatedRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryResponse = json["QueryResponse"] as? [String: Any],
              let accounts = queryResponse["Account"] as? [[String: Any]] else {
            return []
        }
        
        return accounts.compactMap { accountDict in
            guard let id = accountDict["Id"] as? String,
                  let name = accountDict["Name"] as? String,
                  let accountType = accountDict["AccountType"] as? String else {
                return nil
            }
            return QBAccount(id: id, name: name, accountType: accountType)
        }
    }
}

// MARK: - Helper Models

struct QBAccount: Identifiable {
    let id: String
    let name: String
    let accountType: String
}

enum QuickBooksError: LocalizedError {
    case missingCredentials
    case missingAccountConfiguration
    case invalidResponse
    case httpError(statusCode: Int)
    case parseError
    case missingSyncToken
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "QuickBooks credentials are missing. Please configure in Settings."
        case .missingAccountConfiguration:
            return "QuickBooks accounts not configured. Please set up Income, COGS, and Asset accounts in Settings."
        case .invalidResponse:
            return "Invalid response from QuickBooks"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parseError:
            return "Failed to parse QuickBooks response"
        case .missingSyncToken:
            return "Missing SyncToken - item may have been modified"
        }
    }
}
