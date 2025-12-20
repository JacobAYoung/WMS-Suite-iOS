//
//  AddJobView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI
import CoreData

struct AddJobView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let customer: Customer
    let job: Job? // nil for new job
    
    @State private var title = ""
    @State private var jobDescription = ""
    @State private var scheduledDate = Date()
    @State private var estimatedHours = 1
    @State private var estimatedMinutes = 0
    @State private var selectedJobType: JobType = .service
    @State private var address = ""
    @State private var notes = ""
    @State private var useCustomerAddress = true
    
    init(customer: Customer, job: Job? = nil) {
        self.customer = customer
        self.job = job
        
        _title = State(initialValue: job?.title ?? "")
        _jobDescription = State(initialValue: job?.jobDescription ?? "")
        _scheduledDate = State(initialValue: job?.scheduledDate ?? Date())
        
        let duration = Int(job?.estimatedDuration ?? 60)
        _estimatedHours = State(initialValue: duration / 60)
        _estimatedMinutes = State(initialValue: duration % 60)
        
        _selectedJobType = State(initialValue: job?.jobTypeEnum ?? .service)
        _address = State(initialValue: job?.address ?? "")
        _notes = State(initialValue: job?.notes ?? "")
        _useCustomerAddress = State(initialValue: (job?.address ?? "").isEmpty)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Job Details") {
                    TextField("Job Title *", text: $title)
                    
                    Picker("Job Type", selection: $selectedJobType) {
                        ForEach(JobType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    
                    TextEditor(text: $jobDescription)
                        .frame(minHeight: 60)
                        .overlay(
                            Group {
                                if jobDescription.isEmpty {
                                    Text("Description (optional)")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section("Schedule") {
                    DatePicker("Date & Time", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        Picker("Hours", selection: $estimatedHours) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        
                        Picker("Minutes", selection: $estimatedMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text("\(minute)m").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                    }
                }
                
                Section("Location") {
                    Toggle("Use Customer Address", isOn: $useCustomerAddress)
                    
                    if !useCustomerAddress {
                        TextEditor(text: $address)
                            .frame(minHeight: 60)
                            .overlay(
                                Group {
                                    if address.isEmpty {
                                        Text("Enter job location")
                                            .foregroundColor(.gray)
                                            .padding(.leading, 4)
                                            .padding(.top, 8)
                                    }
                                },
                                alignment: .topLeading
                            )
                    } else if let customerAddress = customer.address, !customerAddress.isEmpty {
                        Text(customerAddress)
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No customer address on file")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if notes.isEmpty {
                                    Text("Job notes (optional)")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
            }
            .navigationTitle(job == nil ? "New Job" : "Edit Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveJob()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveJob() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let jobToSave: Job
        if let existingJob = job {
            jobToSave = existingJob
        } else {
            jobToSave = Job(context: viewContext)
            jobToSave.id = Int32(Date().timeIntervalSince1970)
            jobToSave.createdDate = Date()
            jobToSave.customer = customer
        }
        
        jobToSave.title = trimmedTitle
        jobToSave.jobDescription = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        jobToSave.scheduledDate = scheduledDate
        jobToSave.estimatedDuration = Int32((estimatedHours * 60) + estimatedMinutes)
        jobToSave.setJobType(selectedJobType)
        jobToSave.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Set address based on toggle
        if useCustomerAddress {
            jobToSave.address = "" // Will use customer address via computed property
        } else {
            jobToSave.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving job: \(error)")
        }
    }
}
