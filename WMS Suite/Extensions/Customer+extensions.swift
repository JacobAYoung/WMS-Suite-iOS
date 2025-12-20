//
//  Customer+extensions.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import Foundation
import CoreData

extension Customer {
    
    // MARK: - Computed Properties
    
    /// Get jobs array sorted by scheduled date
    var jobsArray: [Job] {
        guard let jobSet = jobs as? Set<Job> else { return [] }
        return Array(jobSet).sorted { ($0.scheduledDate ?? Date.distantPast) > ($1.scheduledDate ?? Date.distantPast) }
    }
    
    /// Get upcoming jobs (not completed, not cancelled, scheduled in future)
    var upcomingJobs: [Job] {
        jobsArray.filter { job in
            !job.isCompleted && !job.isCancelled &&
            (job.scheduledDate ?? Date.distantPast) >= Date()
        }
    }
    
    /// Get past/completed jobs
    var completedJobs: [Job] {
        jobsArray.filter { $0.isCompleted }
    }
    
    /// Get total number of jobs
    var totalJobs: Int {
        jobsArray.count
    }
    
    /// Get display name (never nil)
    var displayName: String {
        name ?? "Unknown Customer"
    }
    
    /// Get formatted phone for display
    var formattedPhone: String? {
        guard let phone = phone, !phone.isEmpty else { return nil }
        // Basic formatting - can enhance later
        return phone
    }
    
    /// Check if customer has contact info
    var hasContactInfo: Bool {
        (email != nil && !email!.isEmpty) ||
        (phone != nil && !phone!.isEmpty)
    }
    
    // MARK: - Fetch Helpers
    
    /// Fetch all customers sorted by name
    static func fetchAllCustomers(context: NSManagedObjectContext) -> [Customer] {
        let request = NSFetchRequest<Customer>(entityName: "Customer")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Customer.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching customers: \(error)")
            return []
        }
    }
    
    /// Search customers by name
    static func searchCustomers(query: String, context: NSManagedObjectContext) -> [Customer] {
        guard !query.isEmpty else {
            return fetchAllCustomers(context: context)
        }
        
        let request = NSFetchRequest<Customer>(entityName: "Customer")
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Customer.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error searching customers: \(error)")
            return []
        }
    }
    
    // MARK: - Quick Actions
    
    /// Get phone URL for calling
    var phoneURL: URL? {
        guard let phone = phone, !phone.isEmpty else { return nil }
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return URL(string: "tel://\(cleaned)")
    }
    
    /// Get SMS URL for texting
    var smsURL: URL? {
        guard let phone = phone, !phone.isEmpty else { return nil }
        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return URL(string: "sms://\(cleaned)")
    }
    
    /// Get email URL for emailing
    var emailURL: URL? {
        guard let email = email, !email.isEmpty else { return nil }
        return URL(string: "mailto:\(email)")
    }
}
