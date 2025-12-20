//
//  AddCustomerView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI
import CoreData

struct AddCustomerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let customer: Customer? // nil for new customer
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var notes = ""
    
    init(customer: Customer? = nil) {
        self.customer = customer
        _name = State(initialValue: customer?.name ?? "")
        _email = State(initialValue: customer?.email ?? "")
        _phone = State(initialValue: customer?.phone ?? "")
        _address = State(initialValue: customer?.address ?? "")
        _notes = State(initialValue: customer?.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Information") {
                    TextField("Name *", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("Address") {
                    TextEditor(text: $address)
                        .frame(minHeight: 80)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(customer == nil ? "New Customer" : "Edit Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCustomer()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveCustomer() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let customerToSave: Customer
        if let existingCustomer = customer {
            customerToSave = existingCustomer
        } else {
            customerToSave = Customer(context: viewContext)
            customerToSave.id = Int32(Date().timeIntervalSince1970)
            customerToSave.createdDate = Date()
        }
        
        customerToSave.name = trimmedName
        customerToSave.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        customerToSave.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        customerToSave.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        customerToSave.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving customer: \(error)")
        }
    }
}
