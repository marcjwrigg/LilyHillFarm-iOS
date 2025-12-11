//
//  PhotoDetailView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData
import Supabase

struct PhotoDetailView: View {
    @ObservedObject var photo: Photo
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var caption: String = ""
    @State private var showingDeleteAlert = false
    @State private var isEditing = false
    @State private var isDeleting = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo
                    photoView
                        .frame(maxWidth: .infinity)
                        .frame(height: 400)
                        .background(Color.black)
                        .clipped()

                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        // Caption
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caption")
                                .font(.headline)

                            if isEditing {
                                TextField("Add a caption...", text: $caption)
                                    .textFieldStyle(.roundedBorder)
                            } else if let caption = photo.caption, !caption.isEmpty {
                                Text(caption)
                                    .foregroundColor(.primary)
                            } else {
                                Text("No caption")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }

                        Divider()

                        // Metadata
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.headline)

                            HStack {
                                Text("Date Taken")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatDate(photo.dateTaken))
                            }

                            HStack {
                                Text("Owner")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(photo.owner)
                            }

                            HStack {
                                Text("Primary Photo")
                                    .foregroundColor(.secondary)
                                Spacer()
                                if photo.isPrimary {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text("Yes")
                                    }
                                } else {
                                    Text("No")
                                }
                            }

                            if photo.fileSize > 0 {
                                HStack {
                                    Text("File Size")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatFileSize(photo.fileSize))
                                }
                            }
                        }

                        Divider()

                        // Actions
                        VStack(spacing: 12) {
                            if !photo.isPrimary {
                                Button(action: makePrimary) {
                                    HStack {
                                        Image(systemName: "star.fill")
                                        Text("Set as Primary")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }

                            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                                HStack {
                                    if isDeleting {
                                        ProgressView()
                                            .tint(.red)
                                        Text("Deleting...")
                                            .fontWeight(.semibold)
                                    } else {
                                        Image(systemName: "trash")
                                        Text("Delete Photo")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(10)
                            }
                            .disabled(isDeleting)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Photo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        saveCaption()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveCaption()
                        }
                        isEditing.toggle()
                    }
                }
            }
            .alert("Delete Photo", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    _Concurrency.Task {
                        await deletePhoto()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this photo? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                caption = photo.caption ?? ""
            }
        }
    }

    // MARK: - Photo View

    @ViewBuilder
    private var photoView: some View {
        #if os(iOS)
        if let image = photo.thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Color(red: 0.9, green: 0.9, blue: 0.9)
                .overlay(
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                )
        }
        #elseif os(macOS)
        if let image = photo.thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Color(red: 0.9, green: 0.9, blue: 0.9)
                .overlay(
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                )
        }
        #endif
    }

    // MARK: - Actions

    private func saveCaption() {
        photo.caption = caption.isEmpty ? nil : caption
        do {
            try viewContext.save()
        } catch {
            print("Error saving caption: \(error)")
        }
    }

    private func makePrimary() {
        photo.makePrimary()
        do {
            try viewContext.save()
        } catch {
            print("Error setting primary photo: \(error)")
        }
    }

    @MainActor
    private func deletePhoto() async {
        isDeleting = true

        // Save photo ID and image path before deletion
        guard let photoId = photo.id else {
            errorMessage = "Photo has no ID"
            showingError = true
            isDeleting = false
            return
        }

        let imagePath = photo.imageAssetPath

        do {
            // Get Supabase instance
            let supabase = SupabaseManager.shared

            // 1. Delete from Supabase database
            print("🗑️ Deleting photo \(photoId.uuidString) from database...")
            let photoRepo = PhotoRepository(context: viewContext)
            try await photoRepo.delete(photoId)
            print("✅ Photo deleted from database")

            // 2. Delete from Supabase Storage if it has a path
            if let path = imagePath, !path.isEmpty {
                print("🗑️ Deleting image from storage: \(path)")
                try await supabase.client.storage
                    .from("photos")
                    .remove(paths: [path])
                print("✅ Image deleted from storage")
            }

            // 3. Delete from local Core Data
            viewContext.delete(photo)
            try viewContext.save()
            print("✅ Photo deleted from Core Data")

            dismiss()
        } catch {
            print("❌ Error deleting photo: \(error)")
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
            showingError = true
            isDeleting = false
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let cattle = Cattle.create(in: context)
    let photo = Photo.create(for: cattle, in: context)
    photo.caption = "Sample photo caption"
    photo.isPrimary = true

    return PhotoDetailView(photo: photo)
        .environment(\.managedObjectContext, context)
}
