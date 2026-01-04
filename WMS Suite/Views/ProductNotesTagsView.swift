//
//  ProductNotesTagsView.swift
//  WMS Suite
//
//  Manage notes and tags for a product
//

import SwiftUI

struct ProductNotesTagsView: View {
    @ObservedObject var item: InventoryItem
    @StateObject private var tagManager = TagManager.shared
    @State private var newNoteText = ""
    @State private var showingAddTag = false
    @State private var showingTagManagement = false
    @State private var refreshTrigger = UUID()  // ⭐ Force refresh when tags/notes change
    @FocusState private var isNoteFieldFocused: Bool
    
    var body: some View {
        List {
            // Tags Section
            Section {
                if item.tags.isEmpty {
                    Text("No tags assigned")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.tags) { tag in
                                TagBadge(tag: tag) {
                                    item.removeTag(tag)
                                    refreshTrigger = UUID()  // ⭐ Refresh after removing
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Button(action: { showingAddTag = true }) {
                    Label("Add Tag", systemImage: "plus.circle")
                }
            } header: {
                Text("Tags")
            }
            
            // Notes Section
            Section {
                // Add new note
                HStack(alignment: .top, spacing: 8) {
                    TextField("Add a note...", text: $newNoteText, axis: .vertical)
                        .focused($isNoteFieldFocused)
                        .lineLimit(3...6)
                    
                    if !newNoteText.isEmpty {
                        Button(action: addNote) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Existing notes
                if item.notes.isEmpty {
                    Text("No notes yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(item.notes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.text)
                                .font(.body)
                            
                            HStack {
                                Text(note.createdDate, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .foregroundColor(.secondary)
                                
                                Text(note.userName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    item.removeNote(note)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Notes")
            }
            
            // Tag Management
            Section {
                NavigationLink(destination: TagManagementView()) {
                    Label("Manage Tags", systemImage: "tag")
                }
            } header: {
                Text("Settings")
            }
        }
        .navigationTitle("Notes & Tags")
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshTrigger)  // ⭐ Force view refresh when this changes
        .sheet(isPresented: $showingAddTag) {
            AddTagSheet(item: item)
        }
        .onChange(of: showingAddTag) { isShowing in
            if !isShowing {
                // ⭐ Refresh when sheet closes
                refreshTrigger = UUID()
            }
        }
    }
    
    private func addNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        
        item.addNote(trimmed)
        newNoteText = ""
        isNoteFieldFocused = false
        refreshTrigger = UUID()  // ⭐ Refresh after adding note
    }
}

// MARK: - Tag Badge

struct TagBadge: View {
    let tag: ProductTag
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.caption)
                .foregroundColor(.white)
            
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tag.color.color)
        .cornerRadius(12)
    }
}

// MARK: - Add Tag Sheet

struct AddTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var item: InventoryItem
    @StateObject private var tagManager = TagManager.shared
    
    var availableTags: [ProductTag] {
        tagManager.availableTags.filter { tag in
            !item.tags.contains(where: { $0.id == tag.id })
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if availableTags.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tag")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("All tags are already assigned")
                            .font(.headline)
                        
                        Text("Create more tags in Tag Management")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(availableTags) { tag in
                        Button(action: {
                            item.addTag(tag)
                            dismiss()
                        }) {
                            HStack {
                                TagBadge(tag: tag)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: TagManagementView()) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// MARK: - Tag Management View

struct TagManagementView: View {
    @StateObject private var tagManager = TagManager.shared
    @State private var newTagName = ""
    @State private var newTagColor: TagColor = .blue
    
    var body: some View {
        List {
            Section {
                ForEach(tagManager.availableTags) { tag in
                    HStack {
                        TagBadge(tag: tag)
                        Spacer()
                        Button(role: .destructive) {
                            tagManager.removeTag(tag)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            } header: {
                Text("Available Tags")
            } footer: {
                Text("Tags can be assigned to products for organization and filtering")
            }
            
            Section {
                TextField("Tag Name", text: $newTagName)
                
                Picker("Color", selection: $newTagColor) {
                    ForEach(TagColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 20, height: 20)
                            Text(color.rawValue.capitalized)
                        }
                        .tag(color)
                    }
                }
                
                Button(action: addNewTag) {
                    Label("Add Tag", systemImage: "plus.circle.fill")
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Create New Tag")
            }
        }
        .navigationTitle("Manage Tags")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addNewTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newTag = ProductTag(name: trimmedName, color: newTagColor)
        tagManager.addTag(newTag)
        
        newTagName = ""
        newTagColor = .blue
    }
}
