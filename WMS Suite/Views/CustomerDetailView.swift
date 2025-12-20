//
//  CustomerDetailView.swift
//  WMS Suite
//
//  Detailed view of customer with contact info and jobs
//

import SwiftUI
import CoreData

struct CustomerDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var customer: Customer
    
    @State private var showingEditCustomer = false
    @State private var showingAddJob = false
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Contact Info Card
                contactInfoSection
                
                // Customer Notes (if any)
                if let notes = customer.notes, !notes.isEmpty {
                    customerNotesSection(notes: notes)
                }
                
                // Quick Actions
                quickActionsSection
                
                // Jobs Section
                jobsSection
            }
            .padding()
        }
        .id(refreshID)
        .navigationTitle(customer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingEditCustomer = true }) {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditCustomer) {
            AddCustomerView(customer: customer)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddJob) {
            AddJobView(customer: customer)
                .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: showingAddJob) { isShowing in
            if !isShowing {
                refreshID = UUID()
            }
        }
        .onChange(of: showingEditCustomer) { isShowing in
            if !isShowing {
                refreshID = UUID()
            }
        }
    }
    
    // MARK: - Contact Info Section
    
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information")
                .font(.headline)
            
            if let phone = customer.phone, !phone.isEmpty {
                HStack {
                    Image(systemName: "phone")
                        .foregroundColor(.secondary)
                    Text("Phone")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(phone)
                        .font(.body)
                }
            }
            
            if let email = customer.email, !email.isEmpty {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.secondary)
                    Text("Email")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(email)
                        .font(.body)
                }
            }
            
            if let address = customer.address, !address.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(.secondary)
                        Text("Address")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(address)
                        .font(.body)
                }
            }
            
            if customer.createdDate != nil {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text("Customer Since")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(customer.createdDate!.formatted(date: .abbreviated, time: .omitted))
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Customer Notes Section
    
    private func customerNotesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
            
            Text(notes)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                if let phoneURL = customer.phoneURL {
                    Link(destination: phoneURL) {
                        QuickActionButton(icon: "phone.fill", label: "Call", color: .green)
                    }
                }
                
                if let smsURL = customer.smsURL {
                    Link(destination: smsURL) {
                        QuickActionButton(icon: "message.fill", label: "Text", color: .blue)
                    }
                }
                
                if let emailURL = customer.emailURL {
                    Link(destination: emailURL) {
                        QuickActionButton(icon: "envelope.fill", label: "Email", color: .orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Jobs Section
    
    private var jobsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Jobs")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddJob = true }) {
                    Label("Add Job", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if customer.totalJobs == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No jobs scheduled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button(action: { showingAddJob = true }) {
                        Text("Schedule First Job")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Upcoming Jobs
                if !customer.upcomingJobs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Upcoming (\(customer.upcomingJobs.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ForEach(customer.upcomingJobs, id: \.id) { job in
                            NavigationLink(destination: JobDetailView(job: job)) {
                                JobRowCompact(job: job)
                            }
                        }
                    }
                }
                
                // Completed Jobs
                if !customer.completedJobs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completed (\(customer.completedJobs.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ForEach(customer.completedJobs.prefix(3), id: \.id) { job in
                            NavigationLink(destination: JobDetailView(job: job)) {
                                JobRowCompact(job: job)
                            }
                        }
                        
                        if customer.completedJobs.count > 3 {
                            Text("Showing 3 of \(customer.completedJobs.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .cornerRadius(10)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Job Row Compact

struct JobRowCompact: View {
    let job: Job
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.displayTitle)
                    .font(.headline)
                
                if let scheduled = job.scheduledDate {
                    Text(scheduled.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let type = job.jobTypeEnum {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                        Text(type.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(Color(type.color))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(job.statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(job.statusColor).opacity(0.2))
                    .foregroundColor(Color(job.statusColor))
                    .cornerRadius(8)
                
                if job.estimatedDuration > 0 {
                    Text(job.formattedDuration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Info Row

// Note: Using inline HStacks instead of separate component for simplicity
