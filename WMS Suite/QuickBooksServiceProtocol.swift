//
//  QuickBooksServiceProtocol.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import Foundation
import CoreData

protocol QuickBooksServiceProtocol {
    // Legacy item methods
    func pushItem(_ item: InventoryItem) async throws -> String
    func syncInventory() async throws -> [InventoryItem]
    
    // Enhanced inventory methods with Core Data
    func syncInventory(context: NSManagedObjectContext, logMessage: @escaping (String) -> Void) async throws
    func pushInventoryItem(_ item: InventoryItem) async throws -> String
    
    // Customer sync
    func syncCustomers(context: NSManagedObjectContext, logMessage: @escaping (String) -> Void) async throws
    
    // Invoice sync
    func syncInvoices(context: NSManagedObjectContext, logMessage: @escaping (String) -> Void) async throws
    func syncInvoice(qbInvoiceId: String, context: NSManagedObjectContext) async throws
    
    // Account management
    func fetchAccounts() async throws -> [QBAccount]
    
    // Credential management
    func updateCredentials(companyId: String, accessToken: String, refreshToken: String)
}
