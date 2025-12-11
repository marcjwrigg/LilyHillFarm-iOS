//
//  MortalityRecordDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Mortality Records with Supabase
//

import Foundation

/// DTO for syncing mortality record data with Supabase
struct MortalityRecordDTO: Codable {
    let id: UUID
    let cattleId: UUID
    let farmId: UUID?
    let deathDate: String?
    let cause: String?
    let category: String?
    let disposalMethod: String?
    let veterinarianCalled: Bool?
    let veterinarianName: String?
    let notes: String?
    let deletedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cattleId = "cattle_id"
        case farmId = "farm_id"
        case deathDate = "death_date"
        case cause
        case category
        case disposalMethod = "disposal_method"
        case veterinarianCalled = "veterinarian_called"
        case veterinarianName = "veterinarian_name"
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

extension MortalityRecordDTO {
    /// Create DTO from Core Data MortalityRecord entity
    init(from record: MortalityRecord) {
        self.id = record.id ?? UUID()
        self.cattleId = record.cattle?.id ?? UUID()
        self.farmId = record.farmId
        self.deathDate = record.deathDate?.toISO8601String()
        self.cause = record.cause
        self.category = record.causeCategory  // iOS uses causeCategory, DB uses category
        self.disposalMethod = record.disposalMethod
        self.veterinarianCalled = record.necropsyPerformed  // Reusing this field
        self.veterinarianName = record.veterinarian
        self.notes = record.notes
        self.deletedAt = record.deletedAt?.toISO8601String()
        self.createdAt = record.createdAt?.toISO8601String()
        // Note: necropsyResults, reportedToAuthorities not in DB - local only
    }

    /// Update Core Data entity from DTO
    func update(_ record: MortalityRecord) {
        record.id = self.id
        // cattle relationship handled separately
        record.farmId = self.farmId
        record.deathDate = self.deathDate?.toDate()
        record.cause = self.cause
        record.causeCategory = self.category  // DB uses category, iOS uses causeCategory
        record.disposalMethod = self.disposalMethod
        record.necropsyPerformed = self.veterinarianCalled ?? false  // Reusing this field
        record.veterinarian = self.veterinarianName
        record.notes = self.notes
        record.deletedAt = self.deletedAt?.toDate()
        record.createdAt = self.createdAt?.toDate()
        // Note: necropsyResults, reportedToAuthorities not synced from DB
    }
}
