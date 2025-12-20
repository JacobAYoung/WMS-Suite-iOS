//
//  AddJobNoteView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI
import CoreData

struct AddJobNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let job: Job
    
    @State private var noteText = ""
    @State private var userName = ""
    @AppStorage("defaultUserName") private var storedUserName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 150)
                }
                
                Section("Your Name") {
                    TextField("Name (optional)", text: $userName)
                }
                
                if !storedUserName.isEmpty {
                    Section {
                        Text("Using saved name: \(storedUserName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                userName = storedUserName
            }
        }
    }
    
    private func saveNote() {
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { return }
        
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save name for future use if provided
        if !trimmedName.isEmpty {
            storedUserName = trimmedName
        }
        
        job.addNote(
            text: trimmedNote,
            userName: trimmedName.isEmpty ? nil : trimmedName,
            context: viewContext
        )
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving note: \(error)")
        }
    }
}
