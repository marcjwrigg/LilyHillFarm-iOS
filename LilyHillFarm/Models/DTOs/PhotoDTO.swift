//
//  PhotoDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Photos with Supabase
//

import Foundation

/// DTO for syncing photo metadata with Supabase
struct PhotoDTO: Codable {
    let id: UUID
    let cattleId: UUID?
    let farmId: UUID?
    let photoUrl: String
    let caption: String?
    let deletedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cattleId = "cattle_id"
        case farmId = "farm_id"
        case photoUrl = "url"  // Database uses "url", iOS uses "photoUrl"
        case caption
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

extension PhotoDTO {
    /// Create DTO from Core Data Photo entity
    init(from photo: Photo) {
        self.id = photo.id ?? UUID()

        // Debug logging to see what relationships are set
        print("📸 Creating PhotoDTO for photo \(photo.id?.uuidString ?? "unknown")")
        print("   Cattle ID: \(photo.cattle?.id?.uuidString ?? "nil")")

        self.cattleId = photo.cattle?.id
        self.farmId = photo.farmId
        self.photoUrl = photo.imageAssetPath ?? ""
        self.caption = photo.caption
        self.deletedAt = photo.deletedAt?.toISO8601String()
        self.createdAt = photo.createdAt?.toISO8601String()
        // Note: iOS Core Data fields not synced: healthRecord, calvingRecord, pregnancyRecord, isPrimary, thumbnailUrl
    }

    /// Update Core Data entity from DTO
    func update(_ photo: Photo) {
        photo.id = self.id
        // Relationships handled separately
        photo.farmId = self.farmId
        photo.imageAssetPath = self.photoUrl
        photo.caption = self.caption
        photo.deletedAt = self.deletedAt?.toDate()
        photo.createdAt = self.createdAt?.toDate()
        // Note: isPrimary, thumbnailUrl not in DB
    }
}

// MARK: - PhotoRecord Support
// Needed by PhotoStorageService for photo uploads

struct PhotoRecord {
    let id: UUID
    let url: String
    let cattleId: UUID?
    let caption: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        url: String,
        cattleId: UUID? = nil,
        caption: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.cattleId = cattleId
        self.caption = caption
        self.createdAt = createdAt
    }

    init(from dto: PhotoDTO) {
        self.id = dto.id
        self.url = dto.photoUrl
        self.cattleId = dto.cattleId
        self.caption = dto.caption
        self.createdAt = dto.createdAt?.toDate() ?? Date()
    }
}

extension PhotoDTO {
    init(from record: PhotoRecord) {
        self.id = record.id
        self.photoUrl = record.url
        self.cattleId = record.cattleId
        self.farmId = nil
        self.caption = record.caption
        self.deletedAt = nil
        self.createdAt = record.createdAt.toISO8601String()
    }
}
