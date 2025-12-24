//
//  CustomerDetailView.swift
//  WMS Suite
//
//  Enhanced detailed view with QuickBooks integration sections
//

import SwiftUI
import CoreData

struct CustomerDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var customer: Customer
    
    @State private var showingEditCustomer = false
    @State private var showingAddJob = false
    @State private var showingAllInvoices = false
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Contact Info Card (EXISTING)
                contactInfoSection
                
                // ✨ NEW: QuickBooks Account Summary
                if customer.quickbooksCustomerId != nil {
                    quickbooksAccountSummarySection
                }
                
                // Customer Notes (EXISTING - if any)
                if let notes = customer.notes, !notes.isEmpty {
                    customerNotesSection(notes: notes)
                }
                
                // Quick Actions (EXISTING)
                quickActionsSection
                
                // ✨ NEW: Invoices Section (if QB customer)
                if customer.quickbooksCustomerId != nil {
                    invoicesSection
                }
                
                // Jobs Section (EXISTING)
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
        .sheet(isPresented: $showingAllInvoices) {
            NavigationView {
                InvoicesListView(customer: customer)
                    .environment(\.managedObjectContext, viewContext)
            }
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
    
    // MARK: - Contact Info Section (EXISTING)
    
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
    
    // MARK: - ✨ NEW: QuickBooks Account Summary Section
    
    private var quickbooksAccountSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("QuickBooks Account")
                    .font(.headline)
                
                Spacer()
                
                // Sync status badge
                if let lastSynced = customer.lastSyncedQuickbooksDate {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Synced \(lastSynced.timeAgoDisplay)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Account Balance
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Balance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // TODO: Wire up actual balance from customer.balance
                        Text("$0.00")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Outstanding")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // TODO: Calculate from unpaid invoices
                        Text("0 invoices")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                
                Divider()
                
                // Quick Stats
                HStack(spacing: 20) {
                    AccountStatBadge(
                        icon: "doc.text.fill",
                        label: "Total Invoices",
                        value: "0", // TODO: Count invoices
                        color: .blue
                    )
                    
                    AccountStatBadge(
                        icon: "dollarsign.circle.fill",
                        label: "Last Payment",
                        value: "Never", // TODO: Last payment date
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - ✨ NEW: Invoices Section
    
    private var invoicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text("Invoices")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAllInvoices = true }) {
                    HStack(spacing: 4) {
                        Text("View All")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            // TODO: Replace with actual invoice data
            // For now, show empty state or skeleton
            if true { // Will be: customer.invoices.isEmpty
                emptyInvoicesState
            } else {
                // Recent invoices list (will be implemented after Invoice entity)
                recentInvoicesList
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var emptyInvoicesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Invoices")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Invoices will appear here after syncing from QuickBooks")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var recentInvoicesList: some View {
        VStack(spacing: 8) {
            // TODO: Loop through customer.recentInvoices (last 3)
            ForEach(0..<3, id: \.self) { index in
                InvoiceRowSkeleton()
            }
            
            Text("Showing 3 most recent invoices")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Customer Notes Section (EXISTING)
    
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
    
    // MARK: - Quick Actions (EXISTING)
    
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
    
    // MARK: - Jobs Section (EXISTING)
    
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

// MARK: - ✨ NEW: Account Stat Badge Component

struct AccountStatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ✨ NEW: Invoice Row Skeleton (temporary)

struct InvoiceRowSkeleton: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("INV-XXXX")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Date placeholder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$XXX.XX")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Status")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Quick Action Button (EXISTING)

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

// MARK: - Job Row Compact (EXISTING)

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

// MARK: - ✨ Helper Extension for Time Ago Display

extension Date {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
