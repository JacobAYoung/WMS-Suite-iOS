//
//  CustomerDetailView.swift
//  WMS Suite
//
//  Enhanced with QuickBooks data integration (WIRED UP VERSION)
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
    
    // QuickBooks invoices for this customer
    var quickbooksInvoices: [Sale] {
        guard let salesSet = customer.sales as? Set<Sale> else { return [] }
        return salesSet
            .filter { $0.source == "quickbooks" }
            .sorted { sale1, sale2 in
                // Sort unpaid invoices first, then by date
                if sale1.paymentStatus != "paid" && sale2.paymentStatus == "paid" {
                    return true
                } else if sale1.paymentStatus == "paid" && sale2.paymentStatus != "paid" {
                    return false
                } else {
                    return (sale1.saleDate ?? Date.distantPast) > (sale2.saleDate ?? Date.distantPast)
                }
            }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Contact Info Card (EXISTING)
                contactInfoSection
                
                // ✨ QuickBooks Account Summary (only if synced)
                if customer.isSyncedWithQuickBooks {
                    quickbooksAccountSummarySection
                }
                
                // Customer Notes (EXISTING - if any)
                if let notes = customer.notes, !notes.isEmpty {
                    customerNotesSection(notes: notes)
                }
                
                // Quick Actions (EXISTING)
                quickActionsSection
                
                // ✨ Invoices Section (only if QB customer)
                if customer.isSyncedWithQuickBooks {
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
    
    // MARK: - ✨ QuickBooks Account Summary Section (WIRED UP)
    
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
                        
                        Text(customer.formattedBalance)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Outstanding")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(customer.unpaidInvoices.count) invoices")
                            .font(.subheadline)
                            .foregroundColor(customer.unpaidInvoices.isEmpty ? .green : .orange)
                    }
                }
                
                Divider()
                
                // Quick Stats
                HStack(spacing: 20) {
                    AccountStatBadge(
                        icon: "doc.text.fill",
                        label: "Total Invoices",
                        value: "\(quickbooksInvoices.count)",
                        color: .blue
                    )
                    
                    AccountStatBadge(
                        icon: "dollarsign.circle.fill",
                        label: "Total Purchases",
                        value: customer.formattedTotalPurchases,
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - ✨ Invoices Section (WIRED UP)
    
    private var invoicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text("Invoices")
                    .font(.headline)
                
                Spacer()
                
                if !quickbooksInvoices.isEmpty {
                    Button(action: { showingAllInvoices = true }) {
                        HStack(spacing: 4) {
                            Text("View All")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
            }
            
            if quickbooksInvoices.isEmpty {
                emptyInvoicesState
            } else {
                // Show recent 3 invoices
                VStack(spacing: 8) {
                    ForEach(quickbooksInvoices.prefix(3), id: \.id) { invoice in
                        NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                            InvoiceRowCompact(invoice: invoice)
                        }
                    }
                    
                    if quickbooksInvoices.count > 3 {
                        Text("Showing 3 of \(quickbooksInvoices.count) invoices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
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

// MARK: - ✨ Account Stat Badge Component

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

// MARK: - ✨ Invoice Row Compact (NEW)

struct InvoiceRowCompact: View {
    let invoice: Sale
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(invoice.orderNumber ?? "Invoice")
                        .font(.headline)
                    
                    // Show QB ID if duplicate invoice numbers exist
                    if let qbId = invoice.quickbooksInvoiceId {
                        Text("(QB: \(qbId))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let date = invoice.saleDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.formattedTotalAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(invoice.paymentStatusDisplayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(invoice.paymentStatusColor.opacity(0.2))
                    .foregroundColor(invoice.paymentStatusColor)
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

// MARK: - Helper Extension for Time Ago Display

extension Date {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
