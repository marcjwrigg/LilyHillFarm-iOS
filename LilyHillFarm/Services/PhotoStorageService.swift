//
//  PhotoStorageService.swift
//  LilyHillFarm
//
//  Service for managing photo uploads to Supabase Storage
//

import Foundation
import UIKit
import Supabase

class PhotoStorageService {
    private let supabase = SupabaseManager.shared

    // MARK: - Upload Photos

    /// Upload a photo to Supabase Storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - cattleId: Optional cattle ID to associate with photo
    ///   - isPrimary: Whether this is the primary photo
    /// - Returns: Photo record with URLs
    func uploadPhoto(
        _ image: UIImage,
        cattleId: UUID? = nil,
        isPrimary: Bool = false
    ) async throws -> PhotoRecord {
        // 1. Compress and convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PhotoStorageError.compressionFailed
        }

        // 2. Generate thumbnail
        let thumbnail = generateThumbnail(from: image, maxSize: 200)
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            throw PhotoStorageError.thumbnailFailed
        }

        // 3. Upload full image
        let fileName = "\(UUID().uuidString).jpg"
        let imageUrl = try await supabase.uploadPhoto(imageData, fileName: fileName)

        // 4. Upload thumbnail
        let thumbFileName = "thumb_\(fileName)"
        _ = try await supabase.uploadPhoto(thumbnailData, fileName: thumbFileName)

        // 5. Create photo record in database
        let photoRecord = PhotoRecord(
            id: UUID(),
            url: imageUrl,
            cattleId: cattleId,
            caption: nil,
            createdAt: Date()
        )

        let dto = PhotoDTO(from: photoRecord)

        let created: PhotoDTO = try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return PhotoRecord(from: created)
    }

    /// Upload multiple photos in batch
    func uploadPhotos(
        _ images: [UIImage],
        cattleId: UUID? = nil
    ) async throws -> [PhotoRecord] {
        var uploadedPhotos: [PhotoRecord] = []

        for (index, image) in images.enumerated() {
            let isPrimary = index == 0 && uploadedPhotos.isEmpty
            let photo = try await uploadPhoto(image, cattleId: cattleId, isPrimary: isPrimary)
            uploadedPhotos.append(photo)
        }

        return uploadedPhotos
    }

    // MARK: - Delete Photos

    /// Delete a photo from storage and database
    func deletePhoto(_ photoId: UUID) async throws {
        // 1. Fetch photo record to get URLs
        let photoDTO: PhotoDTO = try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .select()
            .eq("id", value: photoId.uuidString)
            .single()
            .execute()
            .value

        // 2. Extract file paths from URLs
        let imagePath = extractPath(from: photoDTO.photoUrl)
        // Note: thumbnailUrl removed from PhotoDTO - thumbnails stored locally only

        // 3. Delete from storage
        try await supabase.deletePhoto(path: imagePath)

        // 4. Delete database record
        try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .delete()
            .eq("id", value: photoId.uuidString)
            .execute()
    }

    // MARK: - Fetch Photos

    /// Fetch all photos for a cattle
    func fetchPhotos(forCattleId cattleId: UUID) async throws -> [PhotoRecord] {
        let photos: [PhotoDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .order("is_primary", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value

        return photos.map { PhotoRecord(from: $0) }
    }

    /// Fetch primary photo for cattle
    func fetchPrimaryPhoto(forCattleId cattleId: UUID) async throws -> PhotoRecord? {
        let photo: PhotoDTO = try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .eq("is_primary", value: true)
            .single()
            .execute()
            .value

        return PhotoRecord(from: photo)
    }

    // MARK: - Update Photos

    /// Set a photo as primary for cattle
    func setPrimaryPhoto(_ photoId: UUID, cattleId: UUID) async throws {
        // 1. Unset all other photos as primary
        try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .update(["is_primary": false])
            .eq("cattle_id", value: cattleId.uuidString)
            .execute()

        // 2. Set this photo as primary
        try await supabase.client
            .from(SupabaseConfig.Tables.photos)
            .update(["is_primary": true])
            .eq("id", value: photoId.uuidString)
            .execute()
    }

    // MARK: - Helper Methods

    /// Generate thumbnail from image
    private func generateThumbnail(from image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = maxSize / max(size.width, size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Extract file path from Supabase Storage URL
    private func extractPath(from url: String) -> String {
        // URL format: https://xxx.supabase.co/storage/v1/object/public/cattle-photos/filename.jpg
        // Extract: filename.jpg
        if let lastComponent = url.components(separatedBy: "/").last {
            return lastComponent
        }
        return url
    }
}

// MARK: - Errors

enum PhotoStorageError: LocalizedError {
    case compressionFailed
    case thumbnailFailed
    case uploadFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .thumbnailFailed:
            return "Failed to generate thumbnail"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        }
    }
}
