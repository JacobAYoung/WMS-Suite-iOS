//
//  QuickBooksServiceProtocol.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import Foundation

protocol QuickBooksServiceProtocol {
    func pushItem(_ item: InventoryItem) async throws -> String
    func syncInventory() async throws -> [InventoryItem]
    func fetchAccounts() async throws -> [QBAccount]
}
