//
//  JobDetailView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI
import CoreData
import PhotosUI

struct JobDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var job: Job
    
    @State private var showingEditJob = false
    @State private var showingAddNote = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var imageCaption = ""
    @State private var showingDeleteConfirmation = false
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Job Info Card
                jobInfoSection
                
                // Customer Info Card
                customerInfoSection
                
                // Status Section
                statusSection
                
                // Photos Section
                photosSection
                
                // Notes Section
                notesSection
                
                // Action Buttons
                if !job.isCompleted && !job.isCancelled {
                    actionButtonsSection
                }
            }
            .padding()
        }
        .id(refreshID)
        .navigationTitle(job.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditJob = true }) {
                        Label("Edit Job", systemImage: "pencil")
                    }
                    
                    if !job.isCompleted && !job.isCancelled {
                        Button(action: { markCompleted() }) {
                            Label("Mark Complete", systemImage: "checkmark.circle")
                        }
                        
                        Button(action: { markCancelled() }) {
                            Label("Cancel Job", systemImage: "xmark.circle")
                        }
                    }
                    
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Job", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditJob) {
            if let customer = job.customer {
                AddJobView(customer: customer, job: job)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddJobNoteView(job: job)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
        .alert("Delete Job?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteJob()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .onChange(of: selectedImage) { image in
            if let image = image {
                savePhoto(image)
            }
        }
        .onChange(of: showingAddNote) { isShowing in
            if !isShowing {
                refreshID = UUID()
            }
        }
        .onChange(of: showingEditJob) { isShowing in
            if !isShowing {
                refreshID = UUID()
            }
        }
    }
    
    // MARK: - Job Info Section
    
    private var jobInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Job Details")
                .font(.headline)
            
            if let type = job.jobTypeEnum {
                HStack(spacing: 8) {
                    Image(systemName: type.icon)
                        .foregroundColor(Color(type.color))
                    Text(type.displayName)
                        .font(.subheadline)
                        .foregroundColor(Color(type.color))
                }
            }
            
            if let scheduled = job.scheduledDate {
                InfoRow(
                    label: "Scheduled",
                    value: scheduled.formatted(date: .abbreviated, time: .shortened)
                )
            }
            
            if job.estimatedDuration > 0 {
                InfoRow(label: "Duration", value: job.formattedDuration)
            }
            
            if let description = job.jobDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(description)
                        .font(.body)
                }
            }
            
            if let address = job.effectiveAddress, !address.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(address)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Customer Info Section
    
    private var customerInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customer")
                .font(.headline)
            
            if let customer = job.customer {
                VStack(alignment: .leading, spacing: 8) {
                    Text(customer.displayName)
                        .font(.body)
                        .bold()
                    
                    if let phone = customer.phone, !phone.isEmpty {
                        Link(destination: customer.phoneURL ?? URL(string: "tel:")!) {
                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.green)
                                Text(phone)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    if let email = customer.email, !email.isEmpty {
                        Link(destination: customer.emailURL ?? URL(string: "mailto:")!) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text(email)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(Color(job.statusColor))
                    .frame(width: 12, height: 12)
                Text(job.statusText)
                    .font(.body)
                    .bold()
                
                Spacer()
                
                if job.isOverdue {
                    Text("OVERDUE")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(4)
                }
            }
            
            if let completedDate = job.completedDate {
                InfoRow(
                    label: "Completed",
                    value: completedDate.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button(action: { showingCamera = true }) {
                        Label("Take Photo", systemImage: "camera")
                    }
                    Button(action: { showingImagePicker = true }) {
                        Label("Choose from Library", systemImage: "photo")
                    }
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if job.photosArray.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No photos yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(job.photosArray, id: \.id) { photo in
                            if let imageData = photo.imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddNote = true }) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if job.notesArray.isEmpty {
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
            } else {
                ForEach(job.notesArray, id: \.id) { note in
                    JobNoteCard(note: note)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: { markCompleted() }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Mark as Completed")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            
            Button(action: { markCancelled() }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Cancel Job")
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Actions
    
    private func savePhoto(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        job.addPhoto(imageData: imageData, caption: imageCaption, context: viewContext)
        
        do {
            try viewContext.save()
            refreshID = UUID()
            selectedImage = nil
            imageCaption = ""
        } catch {
            print("Error saving photo: \(error)")
        }
    }
    
    private func markCompleted() {
        job.markCompleted(context: viewContext)
        refreshID = UUID()
    }
    
    private func markCancelled() {
        job.markCancelled(context: viewContext)
        refreshID = UUID()
    }
    
    private func deleteJob() {
        viewContext.delete(job)
        
        do {
            try viewContext.save()
        } catch {
            print("Error deleting job: \(error)")
        }
    }
}

// MARK: - Job Note Card

struct JobNoteCard: View {
    let note: JobNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let userName = note.userName, !userName.isEmpty {
                Text(userName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(note.noteText ?? "")
                .font(.body)
            
            if let date = note.createdDate {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
}
