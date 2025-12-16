//
//  ShopifyError.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation

enum ShopifyError: LocalizedError {
    case missingCredentials
    case invalidResponse
    case httpError(statusCode: Int)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Shopify credentials are missing. Please configure in Settings."
        case .invalidResponse:
            return "Invalid response from Shopify"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parseError:
            return "Failed to parse Shopify response"
        }
    }
}
