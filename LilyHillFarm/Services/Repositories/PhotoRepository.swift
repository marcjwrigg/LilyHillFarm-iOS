//
//  PhotoRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Photos with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class PhotoRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all photos from Supabase
    func fetchAll() async throws -> [PhotoDTO] {
        try requireAuth()

        let photos: [PhotoDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        return photos
    }

    /// Fetch photos for specific cattle
    func fetchByCattleId(_ cattleId: UUID) async throws -> [PhotoDTO] {
        try requireAuth()

        let photos: [PhotoDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return photos
    }

    // MARK: - Create/Update/Delete

    /// Create new photo in Supabase
    func create(_ photo: Photo) async throws -> PhotoDTO {
        try requireAuth()

        let dto = PhotoDTO(from: photo)

        let created: PhotoDTO = try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing photo in Supabase
    func update(_ photo: Photo) async throws -> PhotoDTO {
        try requireAuth()

        guard let id = photo.id else {
            throw RepositoryError.invalidData
        }

        let dto = PhotoDTO(from: photo)

        // Try to update - if no rows affected, create instead
        let updated: [PhotoDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value

        if let first = updated.first {
            return first
        } else {
            // Record doesn't exist, create it instead
            print("   ℹ️ Photo not found in Supabase, creating new record...")
            return try await create(photo)
        }
    }

    /// Soft delete photo from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let record = try self.context.fetch(fetchRequest).first {
                record.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all photos: fetch from Supabase and update Core Data with deletion support
    /// Note: Photos use simplified sync due to image download complexity
    func syncFromSupabase() async throws {
        try await syncWithDeletions(
            entityType: Photo.self,
            tableName: SupabaseConfig.Tables.photos,
            updateEntity: { (photo: Photo, dto: Any) in
                guard let dict = dto as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let photoDTO = try? JSONDecoder().decode(PhotoDTO.self, from: data) else {
                    throw RepositoryError.invalidData
                }

                // Update from DTO (without image download - done separately if needed)
                photoDTO.update(photo)

                // Resolve cattle relationship
                if let cattleId = photoDTO.cattleId {
                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                    if let cattle = try self.context.fetch(cattleFetch).first {
                        photo.cattle = cattle
                    }
                }
            },
            extractId: { dto in
                guard let dict = dto as? [String: Any],
                      let idString = dict["id"] as? String,
                      let id = UUID(uuidString: idString) else {
                    return UUID()
                }
                return id
            },
            hasFarmId: false
        )
    }

    /// Push local photo to Supabase
    func pushToSupabase(_ photo: Photo) async throws {
        try requireAuth()

        guard let photoId = photo.id else {
            print("❌ Photo has no ID, cannot push to Supabase")
            return
        }

        print("📤 Uploading photo \(photoId.uuidString) to Supabase...")

        // Check if this is a new photo (needs image upload)
        let needsImageUpload = photo.imageAssetPath == nil || photo.imageAssetPath?.isEmpty == true

        // If photo has thumbnail data but no URL, upload the image first
        if needsImageUpload {
            if let thumbnailData = photo.thumbnailData {
                print("   📸 Photo has local thumbnail data, uploading to Storage...")
                try await uploadImageToStorage(photo, thumbnailData: thumbnailData)
            } else {
                print("   ⚠️ Photo has no thumbnail data and no URL, skipping upload")
                return
            }
        }

        // Refetch the photo to ensure all relationships are loaded
        let refreshedPhoto = try await context.perform { [weak self] in
            guard let self = self else { return photo }
            let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", photoId as CVarArg)
            fetchRequest.relationshipKeyPathsForPrefetching = ["cattle", "healthRecord"]

            if let fetched = try self.context.fetch(fetchRequest).first {
                print("   ✅ Refreshed photo from context")
                return fetched
            }
            print("   ⚠️ Could not refresh photo, using original")
            return photo
        }

        // Try to update first, if it fails (doesn't exist), create
        do {
            print("   📝 Updating photo metadata in database...")
            _ = try await update(refreshedPhoto)
        } catch {
            print("   📝 Photo doesn't exist, creating new record...")
            _ = try await create(refreshedPhoto)
        }

        print("✅ Photo uploaded successfully!")
    }

    // MARK: - Upload to Storage

    /// Upload image data to Supabase Storage and update photo record with URL
    private func uploadImageToStorage(_ photo: Photo, thumbnailData: Data) async throws {
        guard photo.id != nil else {
            throw RepositoryError.invalidData
        }

        // Determine the parent entity ID for folder structure
        let parentFolderId: String
        if let cattleId = photo.cattle?.id {
            parentFolderId = cattleId.uuidString
        } else if let healthRecordId = photo.healthRecord?.id {
            parentFolderId = healthRecordId.uuidString
        } else {
            parentFolderId = "other"
        }

        // Generate file path: cattle-photos/{parent-id}/{timestamp}.jpeg
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let fileName = "\(timestamp).jpeg"
        let filePath = "cattle-photos/\(parentFolderId)/\(fileName)"

        print("   🗂️ Uploading to: \(filePath)")

        // Upload to Supabase Storage
        do {
            _ = try await supabase.client.storage
                .from("photos")
                .upload(
                    filePath,
                    data: thumbnailData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )

            print("   ✅ Image uploaded to Storage")

            // Update photo record with the storage path
            await context.perform {
                photo.imageAssetPath = filePath
            }

            // Save the updated path
            try await context.perform {
                try self.context.save()
            }

            print("   ✅ Photo path saved to Core Data")
        } catch {
            print("   ❌ Failed to upload image to Storage: \(error)")
            throw error
        }
    }

    // MARK: - Download Images

    /// Download image from Supabase Storage
    func downloadImage(from url: String) async throws -> Data {
        // If URL is just a path, use Supabase Storage API with authentication
        if !url.starts(with: "http://") && !url.starts(with: "https://") {
            // Use authenticated Supabase Storage download
            print("   📥 Downloading via authenticated Supabase Storage API")
            print("   🗂️ Bucket: photos, Path: \(url)")

            do {
                let data = try await supabase.client.storage
                    .from("photos")
                    .download(path: url)

                print("   ✅ Downloaded \(data.count) bytes via Storage API")
                return data
            } catch {
                print("   ❌ Storage API download failed: \(error)")
                throw RepositoryError.invalidData
            }
        } else {
            // It's already a full URL, download directly
            print("   🌐 Downloading from full URL: \(url)")

            guard let imageUrl = URL(string: url) else {
                throw RepositoryError.invalidData
            }

            let (data, response) = try await URLSession.shared.data(from: imageUrl)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("   ⚠️ HTTP Status: \(((response as? HTTPURLResponse)?.statusCode ?? -1))")
                throw RepositoryError.invalidData
            }

            return data
        }
    }
}
