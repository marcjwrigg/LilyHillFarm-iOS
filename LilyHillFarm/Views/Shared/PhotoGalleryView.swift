//
//  PhotoGalleryView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData
import Supabase

struct PhotoGalleryView: View {
    let photos: [Photo]
    let entityName: String
    let onAddPhoto: () -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: Photo?
    @State private var showingPhotoDetail = false
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var isDeleting = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("\(photos.count) Photo\(photos.count == 1 ? "" : "s")")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(entityName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Add Photo Button
                Button(action: onAddPhoto) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Photos")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                // Photo Grid
                if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No photos yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Tap 'Add Photos' to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(photos, id: \.objectID) { photo in
                            PhotoGridItem(photo: photo)
                                .onTapGesture {
                                    selectedPhoto = photo
                                    showingPhotoDetail = true
                                }
                                .contextMenu {
                                    Button {
                                        makePrimary(photo)
                                    } label: {
                                        Label("Set as Primary", systemImage: "star.fill")
                                    }

                                    Button(role: .destructive) {
                                        photoToDelete = photo
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Photos")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingPhotoDetail) {
            if let photo = selectedPhoto {
                PhotoDetailView(photo: photo)
            }
        }
        .alert("Delete Photo", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                guard let photo = photoToDelete else { return }
                _Concurrency.Task {
                    await deletePhoto(photo)
                }
            }
        } message: {
            Text("Are you sure you want to delete this photo?")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .disabled(isDeleting)
    }

    // MARK: - Actions

    private func makePrimary(_ photo: Photo) {
        photo.makePrimary()
        do {
            try viewContext.save()
        } catch {
            print("Error setting primary photo: \(error)")
        }
    }

    @MainActor
    private func deletePhoto(_ photo: Photo) async {
        isDeleting = true

        // Save photo ID and image path before deletion
        guard let photoId = photo.id else {
            errorMessage = "Photo has no ID"
            showingError = true
            isDeleting = false
            return
        }

        let imagePath = photo.imageAssetPath

        // Create repository with viewContext
        let photoRepo = PhotoRepository(context: viewContext)

        do {
            // Get Supabase instance
            let supabase = SupabaseManager.shared

            // 1. Delete from Supabase database
            print("🗑️ Deleting photo \(photoId.uuidString) from database...")
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

            isDeleting = false
        } catch {
            print("❌ Error deleting photo: \(error)")
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
            showingError = true
            isDeleting = false
        }
    }
}

// MARK: - Photo Grid Item

struct PhotoGridItem: View {
    let photo: Photo

    var body: some View {
        ZStack(alignment: .topTrailing) {
            #if os(iOS)
            if let image = photo.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                    .frame(width: 110, height: 110)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            #elseif os(macOS)
            if let image = photo.thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                    .frame(width: 110, height: 110)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            #endif

            // Primary indicator
            if photo.isPrimary {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding(4)
            }
        }
    }
}

#Preview {
    NavigationView {
        PhotoGalleryView(
            photos: [],
            entityName: "Sample Cow",
            onAddPhoto: {
                print("Add photo tapped")
            }
        )
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
