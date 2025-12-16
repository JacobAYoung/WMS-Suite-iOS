//
//  NetworkService.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/14/25.
//

import Foundation

class NetworkService {
    
    // Create a custom URLSession with better configuration
    private static let customSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60 // 60 seconds
        config.timeoutIntervalForResource = 120 // 2 minutes
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: config)
    }()
    
    static func performRequest(request: URLRequest, maxRetries: Int = 3) async throws -> (Data, URLResponse) {
        var lastError: Error?
        var modifiedRequest = request
        
        // Ensure proper timeout
        if modifiedRequest.timeoutInterval == 60 {
            modifiedRequest.timeoutInterval = 60
        }
        
        for attempt in 0..<maxRetries {
            print("Network attempt \(attempt + 1) of \(maxRetries)")
            
            do {
                let (data, response) = try await customSession.data(for: modifiedRequest)
                print("Request successful")
                return (data, response)
            } catch let error as NSError {
                lastError = error
                print("Request failed with error: \(error.domain) code: \(error.code)")
                
                // Check if it's a network connectivity error that we should retry
                if error.domain == NSURLErrorDomain {
                    switch error.code {
                    case NSURLErrorNetworkConnectionLost,
                         NSURLErrorNotConnectedToInternet,
                         NSURLErrorTimedOut,
                         NSURLErrorCannotConnectToHost,
                         NSURLErrorDNSLookupFailed,
                         -1005: // Network connection lost
                        
                        // Don't retry on last attempt
                        if attempt < maxRetries - 1 {
                            // Wait before retrying (exponential backoff)
                            let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000 // 1s, 2s, 4s
                            print("Waiting \(Double(delay) / 1_000_000_000)s before retry...")
                            try? await Task.sleep(nanoseconds: delay)
                            continue
                        }
                        
                    default:
                        // Other errors shouldn't be retried
                        throw error
                    }
                } else {
                    // Non-network errors shouldn't be retried
                    throw error
                }
            }
        }
        
        // If we get here, all retries failed
        throw lastError ?? NetworkError.maxRetriesExceeded
    }
}

enum NetworkError: LocalizedError {
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Network request failed after multiple attempts. Please check your internet connection and try again."
        }
    }
}
