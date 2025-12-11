//
//  CalvingRecordDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Calving Records with Supabase
//

import Foundation

/// DTO for syncing calving record data with Supabase
struct CalvingRecordDTO: Codable {
    let id: UUID
    let damId: UUID
    let sireId: UUID?
    let calfId: UUID?
    let farmId: UUID?
    let pregnancyId: UUID?
    let calvingDate: String?
    let difficulty: String?
    let calfSex: String?
    let calfBirthWeight: Double?
    let calfVigor: String?
    let complications: String?
    let retainedPlacenta: Bool?
    let assistanceProvided: String?
    let veterinarianCalled: Bool?
    let notes: String?
    let deletedAt: String?  // For soft delete sync
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case damId = "dam_id"
        case sireId = "sire_id"
        case calfId = "calf_id"
        case farmId = "farm_id"
        case pregnancyId = "pregnancy_id"
        case calvingDate = "calving_date"
        case difficulty = "calving_ease"  // Maps iOS 'difficulty' to DB 'calving_ease'
        case calfSex = "calf_sex"
        case calfBirthWeight = "birth_weight"  // Maps iOS 'calfBirthWeight' to DB 'birth_weight'
        case calfVigor = "calf_vigor"
        case complications
        case retainedPlacenta = "retained_placenta"
        case assistanceProvided = "assistance_provided"
        case veterinarianCalled = "veterinarian_called"
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

extension CalvingRecordDTO {
    /// Create DTO from Core Data CalvingRecord entity
    init(from record: CalvingRecord) {
        self.id = record.id ?? UUID()
        self.damId = record.dam?.id ?? UUID()
        self.sireId = record.sire?.id
        self.calfId = record.calf?.id
        self.farmId = record.farmId
        self.pregnancyId = record.pregnancyId
        self.calvingDate = record.calvingDate?.toISO8601String()
        self.difficulty = record.difficulty ?? ""
        // Map iOS sex values to database-compatible values (DB only allows 'Bull' or 'Heifer')
        self.calfSex = Self.mapCalfSexForDatabase(record.calfSex ?? "")
        self.calfBirthWeight = record.calfBirthWeight?.doubleValue
        self.calfVigor = record.calfVigor
        self.complications = record.complications
        self.retainedPlacenta = record.retainedPlacenta
        self.assistanceProvided = record.assistanceProvided
        self.veterinarianCalled = record.veterinarianCalled
        self.notes = record.notes
        self.deletedAt = record.deletedAt?.toISO8601String()
        self.createdAt = record.createdAt?.toISO8601String()
    }

    /// Map iOS calf sex values to database-compatible values
    /// Database constraint only allows 'Bull' or 'Heifer'
    private static func mapCalfSexForDatabase(_ sex: String) -> String {
        switch sex {
        case "Steer", "Bull":
            return "Bull"  // Steer is a castrated bull, map to Bull for DB
        case "Heifer", "Cow":
            return "Heifer"  // Cow is an adult female, map to Heifer for calves
        default:
            return ""  // Empty string for unknown/missing values
        }
    }

    /// Update Core Data entity from DTO
    func update(_ record: CalvingRecord) {
        record.id = self.id
        // Relationships (dam, sire, calf) handled separately
        record.farmId = self.farmId
        record.pregnancyId = self.pregnancyId
        record.calvingDate = self.calvingDate?.toDate()
        record.difficulty = self.difficulty ?? ""
        record.calfSex = self.calfSex ?? ""
        record.calfBirthWeight = self.calfBirthWeight.map { NSDecimalNumber(value: $0) }
        record.calfVigor = self.calfVigor
        record.complications = self.complications
        record.retainedPlacenta = self.retainedPlacenta ?? false
        record.assistanceProvided = self.assistanceProvided
        record.veterinarianCalled = self.veterinarianCalled ?? false
        record.notes = self.notes
        record.deletedAt = self.deletedAt?.toDate()
        record.createdAt = self.createdAt?.toDate()
    }
}
