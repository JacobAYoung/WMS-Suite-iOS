//
//  AddOrderNoteView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/19/25.
//

import SwiftUI

struct AddOrderNoteView: View {
    @Environment(\.dismiss) private var dismiss
    let sale: Sale
    let onSave: (String, String) -> Void
    
    @State private var noteText = ""
    @State private var userName = ""
    @State private var showingUserPrompt = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 120)
                }
                
                Section("Your Name") {
                    TextField("Enter your name", text: $userName)
                }
                
                Section {
                    Text("Your name will be attached to this note for tracking purposes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        }
    }
    
    private func saveNote() {
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedNote.isEmpty else { return }
        
        let finalName = trimmedName.isEmpty ? "Unknown" : trimmedName
        onSave(trimmedNote, finalName)
        dismiss()
    }
}
