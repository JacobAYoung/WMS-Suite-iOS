//
//  OrderNotesView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/19/25.
//

import SwiftUI
import CoreData

struct OrderNotesView: View {
    let sale: Sale
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddNote = false
    
    var notes: [OrderNote] {
        sale.notesArray
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes & History")
                    .font(.headline)
                
                Spacer()
                
                if !notes.isEmpty {
                    Text("\(notes.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if notes.isEmpty {
                emptyNotesView
            } else {
                notesListView
            }
            
            Button(action: { showingAddNote = true }) {
                Label("Add Note", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddOrderNoteView(sale: sale) { noteText, userName in
                addNote(text: noteText, userName: userName)
            }
        }
    }
    
    private var emptyNotesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("No notes yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var notesListView: some View {
        VStack(spacing: 8) {
            ForEach(notes, id: \.id) { note in
                OrderNoteCard(note: note)
            }
        }
    }
    
    private func addNote(text: String, userName: String) {
        sale.addNote(
            text: text,
            type: OrderNoteType.general.rawValue,
            userName: userName,
            context: viewContext
        )
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving note: \(error)")
        }
    }
}

// MARK: - Order Note Card

struct OrderNoteCard: View {
    let note: OrderNote
    
    var noteType: OrderNoteType? {
        guard let typeString = note.noteType else { return nil }
        return OrderNoteType(rawValue: typeString)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: noteType?.icon ?? "note.text")
                    .foregroundColor(iconColor)
                
                Text(noteType?.displayText ?? "Note")
                    .font(.subheadline)
                    .bold()
                
                Spacer()
                
                if let date = note.createdDate {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let text = note.noteText, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            if let userName = note.userName, !userName.isEmpty {
                Text("by \(userName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var iconColor: Color {
        guard let type = noteType else { return .gray }
        
        switch type {
        case .general:
            return .blue
        case .prioritySet, .attentionSet:
            return .red
        case .priorityRemoved, .attentionRemoved:
            return .green
        case .statusChanged:
            return .orange
        }
    }
}
