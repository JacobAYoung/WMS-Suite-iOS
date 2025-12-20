//
//  Job+Extensions.swift
//  WMS Suite
//
//  Extensions for Job entity
//

import Foundation
import CoreData
import UIKit

extension Job {
    
    // MARK: - Computed Properties
    
    /// Get job type as enum
    var jobTypeEnum: JobType? {
        guard let typeString = jobType else { return nil }
        return JobType(rawValue: typeString)
    }
    
    /// Set job type from enum
    func setJobType(_ type: JobType) {
        jobType = type.rawValue
    }
    
    /// Get photos array sorted by date
    var photosArray: [JobPhoto] {
        guard let photoSet = photos as? Set<JobPhoto> else { return [] }
        return Array(photoSet).sorted { ($0.takenDate ?? Date.distantPast) > ($1.takenDate ?? Date.distantPast) }
    }
    
    /// Get notes array sorted by date (newest first)
    var notesArray: [JobNote] {
        guard let noteSet = jobNotes as? Set<JobNote> else { return [] }
        return Array(noteSet).sorted { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
    }
    
    /// Get display title (never nil)
    var displayTitle: String {
        title ?? "Untitled Job"
    }
    
    /// Get formatted duration
    var formattedDuration: String {
        guard estimatedDuration > 0 else { return "Not set" }
        
        let hours = estimatedDuration / 60
        let minutes = estimatedDuration % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Check if job is upcoming
    var isUpcoming: Bool {
        guard let scheduled = scheduledDate else { return false }
        return !isCompleted && !isCancelled && scheduled >= Date()
    }
    
    /// Check if job is overdue
    var isOverdue: Bool {
        guard let scheduled = scheduledDate else { return false }
        return !isCompleted && !isCancelled && scheduled < Date()
    }
    
    /// Get status display text
    var statusText: String {
        if isCancelled {
            return "Cancelled"
        } else if isCompleted {
            return "Completed"
        } else if isOverdue {
            return "Overdue"
        } else {
            return "Scheduled"
        }
    }
    
    /// Get status color
    var statusColor: UIColor {
        if isCancelled {
            return .systemRed
        } else if isCompleted {
            return .systemGreen
        } else if isOverdue {
            return .systemOrange
        } else {
            return .systemBlue
        }
    }
    
    /// Get effective address (job address or customer address)
    var effectiveAddress: String? {
        if let jobAddress = address, !jobAddress.isEmpty {
            return jobAddress
        }
        return customer?.address
    }
    
    // MARK: - Photo Management
    
    /// Add a photo to this job
    func addPhoto(imageData: Data, caption: String?, context: NSManagedObjectContext) {
        let photo = JobPhoto(context: context)
        photo.id = Int32(Date().timeIntervalSince1970)
        photo.imageData = imageData
        photo.caption = caption
        photo.takenDate = Date()
        photo.job = self
    }
    
    /// Delete a photo
    func deletePhoto(_ photo: JobPhoto, context: NSManagedObjectContext) {
        context.delete(photo)
    }
    
    // MARK: - Note Management
    
    /// Add a note to this job
    func addNote(text: String, userName: String?, context: NSManagedObjectContext) {
        let note = JobNote(context: context)
        note.id = Int32(Date().timeIntervalSince1970)
        note.noteText = text
        note.createdDate = Date()
        note.userName = userName
        note.job = self
    }
    
    // MARK: - Fetch Helpers
    
    /// Fetch all jobs sorted by scheduled date
    static func fetchAllJobs(context: NSManagedObjectContext) -> [Job] {
        let request = NSFetchRequest<Job>(entityName: "Job")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Job.scheduledDate, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching jobs: \(error)")
            return []
        }
    }
    
    /// Fetch upcoming jobs
    static func fetchUpcomingJobs(context: NSManagedObjectContext) -> [Job] {
        let request = NSFetchRequest<Job>(entityName: "Job")
        request.predicate = NSPredicate(
            format: "isCompleted == NO AND isCancelled == NO AND scheduledDate >= %@",
            Date() as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Job.scheduledDate, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching upcoming jobs: \(error)")
            return []
        }
    }
    
    /// Fetch jobs for a specific date
    static func fetchJobs(for date: Date, context: NSManagedObjectContext) -> [Job] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        let request = NSFetchRequest<Job>(entityName: "Job")
        request.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND scheduledDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Job.scheduledDate, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching jobs for date: \(error)")
            return []
        }
    }
    
    // MARK: - Actions
    
    /// Mark job as completed
    func markCompleted(context: NSManagedObjectContext) {
        isCompleted = true
        completedDate = Date()
        
        // Update customer last contact date
        customer?.lastContactDate = Date()
        
        do {
            try context.save()
        } catch {
            print("Error marking job completed: \(error)")
        }
    }
    
    /// Mark job as cancelled
    func markCancelled(context: NSManagedObjectContext) {
        isCancelled = true
        
        do {
            try context.save()
        } catch {
            print("Error marking job cancelled: \(error)")
        }
    }
    
    /// Reschedule job
    func reschedule(to newDate: Date, context: NSManagedObjectContext) {
        scheduledDate = newDate
        
        do {
            try context.save()
        } catch {
            print("Error rescheduling job: \(error)")
        }
    }
}
