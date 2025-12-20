//
//  CustomersView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI
import CoreData

struct CustomersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Customer.name, ascending: true)],
        animation: .default)
    private var customers: FetchedResults<Customer>
    
    @State private var searchText = ""
    @State private var showingAddCustomer = false
    @State private var showingCalendar = false
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return Array(customers)
        } else {
            return customers.filter { customer in
                customer.name?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if filteredCustomers.isEmpty {
                    emptyStateView
                } else {
                    customersList
                }
            }
            .navigationTitle("Customers")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingCalendar = true }) {
                        Image(systemName: "calendar")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCustomer = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search customers...")
            .sheet(isPresented: $showingAddCustomer) {
                AddCustomerView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingCalendar) {
                NavigationView {
                    CalendarView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }
    
    // MARK: - Customers List
    
    private var customersList: some View {
        List {
            ForEach(filteredCustomers, id: \.id) { customer in
                NavigationLink(destination: CustomerDetailView(customer: customer)) {
                    CustomerRow(customer: customer)
                }
            }
            .onDelete(perform: deleteCustomers)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Customers" : "No Results")
                .font(.title2)
                .bold()
            
            Text(searchText.isEmpty ?
                 "Add your first customer to get started" :
                 "No customers match \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Button(action: { showingAddCustomer = true }) {
                    Label("Add Customer", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    
    private func deleteCustomers(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let customer = filteredCustomers[index]
                viewContext.delete(customer)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting customers: \(error)")
            }
        }
    }
}

// MARK: - Customer Row

struct CustomerRow: View {
    let customer: Customer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Customer name
            Text(customer.displayName)
                .font(.headline)
            
            // Contact info
            HStack(spacing: 16) {
                if let phone = customer.phone, !phone.isEmpty {
                    Label(phone, systemImage: "phone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let email = customer.email, !email.isEmpty {
                    Label(email, systemImage: "envelope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Job stats
            if customer.totalJobs > 0 {
                HStack(spacing: 16) {
                    Label("\(customer.upcomingJobs.count) upcoming", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Label("\(customer.completedJobs.count) completed", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
