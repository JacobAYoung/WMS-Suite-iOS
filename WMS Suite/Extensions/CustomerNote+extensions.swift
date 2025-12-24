//
//  CustomerNote+Extensions.swift
//  WMS Suite
//
//  Helper extensions for CustomerNote entity
//

import Foundation
import CoreData
import SwiftUI

extension CustomerNote {
    
    // MARK: - Computed Properties
    
    /// Get note type enum
    var noteTypeEnum: CustomerNoteType {
        guard let type = noteType else { return .general }
        return CustomerNoteType(rawValue: type) ?? .general
    }
    
    /// Set note type from enum
    func setNoteType(_ type: CustomerNoteType) {
        self.noteType = type.rawValue
    }
    
    /// Get formatted date string
    var formattedDate: String {
        guard let date = createdDate else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Get relative time string (e.g., "2 hours ago")
    var relativeTimeString: String {
        guard let date = createdDate else { return "Unknown time" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Get display user name (or "You" if no userName)
    var displayUserName: String {
        userName ?? "You"
    }
    
    /// Get note preview (first 50 characters)
    var preview: String {
        guard let text = noteText else { return "" }
        if text.count <= 50 {
            return text
        }
        return String(text.prefix(50)) + "..."
    }
    
    // MARK: - Fetch Helpers
    
    /// Fetch notes for a customer
    static func fetchNotes(for customer: Customer, context: NSManagedObjectContext) -> [CustomerNote] {
        let request = NSFetchRequest<CustomerNote>(entityName: "CustomerNote")
        request.predicate = NSPredicate(format: "customer == %@", customer)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CustomerNote.createdDate, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching customer notes: \(error)")
            return []
        }
    }
    
    /// Fetch notes by type
    static func fetchNotes(for customer: Customer, ofType type: CustomerNoteType, context: NSManagedObjectContext) -> [CustomerNote] {
        let request = NSFetchRequest<CustomerNote>(entityName: "CustomerNote")
        request.predicate = NSPredicate(format: "customer == %@ AND noteType == %@", customer, type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CustomerNote.createdDate, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching typed customer notes: \(error)")
            return []
        }
    }
    
    /// Create a new note for customer
    static func create(
        for customer: Customer,
        noteText: String,
        type: CustomerNoteType = .general,
        userName: String? = nil,
        context: NSManagedObjectContext
    ) -> CustomerNote {
        let note = CustomerNote(context: context)
        note.id = Int32(Date().timeIntervalSince1970)
        note.noteText = noteText
        note.noteType = type.rawValue
        note.userName = userName
        note.createdDate = Date()
        note.customer = customer
        
        return note
    }
}
