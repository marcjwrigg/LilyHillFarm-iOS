//
//  PregnancyRecordDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Pregnancy Records with Supabase
//

import Foundation

/// DTO for syncing pregnancy record data with Supabase
struct PregnancyRecordDTO: Codable {
    let id: UUID
    let damId: UUID
    let sireId: UUID?
    let farmId: UUID?
    // New range-based date fields
    let breedingStartDate: String?
    let breedingEndDate: String?
    let expectedCalvingStartDate: String?
    let expectedCalvingEndDate: String?
    // Legacy single-date fields (for backwards compatibility)
    let breedingDate: String?
    let expectedCalvingDate: String?
    let pregnancyStatus: String?
    let breedingMethod: String?
    let aiTechnician: String?
    let semenSource: String?
    let externalBullName: String?
    let externalBullRegistration: String?
    let confirmationMethod: String?
    let confirmationDate: String?
    let notes: String?
    let deletedAt: String?  // For soft delete sync
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case damId = "cow_id"  // Database uses "cow_id" for the pregnant cow
        case sireId = "bull_id"  // Database uses "bull_id" for the sire
        case farmId = "farm_id"
        case breedingStartDate = "breeding_start_date"
        case breedingEndDate = "breeding_end_date"
        case expectedCalvingStartDate = "expected_calving_start_date"
        case expectedCalvingEndDate = "expected_calving_end_date"
        case breedingDate = "breeding_date"  // Legacy single date field
        case expectedCalvingDate = "expected_calving_date"  // Legacy single date field
        case pregnancyStatus = "status"  // Database uses "status", iOS uses "pregnancyStatus"
        case breedingMethod = "breeding_method"
        case aiTechnician = "ai_technician"
        case semenSource = "semen_source"
        case externalBullName = "external_bull_name"
        case externalBullRegistration = "external_bull_registration"
        case confirmationMethod = "confirmation_method"
        case confirmationDate = "confirmed_date"  // Database uses "confirmed_date", not "confirmation_date"
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }

    // Memberwise initializer
    init(
        id: UUID,
        damId: UUID,
        sireId: UUID?,
        farmId: UUID?,
        breedingStartDate: String?,
        breedingEndDate: String?,
        expectedCalvingStartDate: String?,
        expectedCalvingEndDate: String?,
        breedingDate: String?,
        expectedCalvingDate: String?,
        pregnancyStatus: String?,
        breedingMethod: String?,
        aiTechnician: String?,
        semenSource: String?,
        externalBullName: String?,
        externalBullRegistration: String?,
        confirmationMethod: String?,
        confirmationDate: String?,
        notes: String?,
        deletedAt: String?,
        createdAt: String?
    ) {
        self.id = id
        self.damId = damId
        self.sireId = sireId
        self.farmId = farmId
        self.breedingStartDate = breedingStartDate
        self.breedingEndDate = breedingEndDate
        self.expectedCalvingStartDate = expectedCalvingStartDate
        self.expectedCalvingEndDate = expectedCalvingEndDate
        self.breedingDate = breedingDate
        self.expectedCalvingDate = expectedCalvingDate
        self.pregnancyStatus = pregnancyStatus
        self.breedingMethod = breedingMethod
        self.aiTechnician = aiTechnician
        self.semenSource = semenSource
        self.externalBullName = externalBullName
        self.externalBullRegistration = externalBullRegistration
        self.confirmationMethod = confirmationMethod
        self.confirmationDate = confirmationDate
        self.notes = notes
        self.deletedAt = deletedAt
        self.createdAt = createdAt
    }

    // Custom decoder to handle both "dam_id/sire_id" (new) and "cow_id/bull_id" (old) column names
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UUID.self, forKey: .id)

        // Try "dam_id" first, fall back to "cow_id" for old records
        if let damId = try? container.decode(UUID.self, forKey: .damId) {
            self.damId = damId
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            self.damId = try legacyContainer.decode(UUID.self, forKey: .cowId)
        }

        // Try "sire_id" first, fall back to "bull_id" for old records
        if let sireId = try? container.decodeIfPresent(UUID.self, forKey: .sireId) {
            self.sireId = sireId
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            self.sireId = try? legacyContainer.decodeIfPresent(UUID.self, forKey: .bullId)
        }

        self.farmId = try? container.decodeIfPresent(UUID.self, forKey: .farmId)
        self.breedingStartDate = try container.decodeIfPresent(String.self, forKey: .breedingStartDate)
        self.breedingEndDate = try container.decodeIfPresent(String.self, forKey: .breedingEndDate)
        self.expectedCalvingStartDate = try container.decodeIfPresent(String.self, forKey: .expectedCalvingStartDate)
        self.expectedCalvingEndDate = try container.decodeIfPresent(String.self, forKey: .expectedCalvingEndDate)
        self.breedingDate = try container.decodeIfPresent(String.self, forKey: .breedingDate)
        self.expectedCalvingDate = try container.decodeIfPresent(String.self, forKey: .expectedCalvingDate)
        self.pregnancyStatus = try container.decodeIfPresent(String.self, forKey: .pregnancyStatus)
        self.breedingMethod = try container.decodeIfPresent(String.self, forKey: .breedingMethod)
        self.aiTechnician = try container.decodeIfPresent(String.self, forKey: .aiTechnician)
        self.semenSource = try container.decodeIfPresent(String.self, forKey: .semenSource)
        self.externalBullName = try container.decodeIfPresent(String.self, forKey: .externalBullName)
        self.externalBullRegistration = try container.decodeIfPresent(String.self, forKey: .externalBullRegistration)
        self.confirmationMethod = try container.decodeIfPresent(String.self, forKey: .confirmationMethod)
        self.confirmationDate = try container.decodeIfPresent(String.self, forKey: .confirmationDate)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    // Legacy coding keys for old database schema
    private enum LegacyCodingKeys: String, CodingKey {
        case cowId = "cow_id"
        case bullId = "bull_id"
    }
}

extension PregnancyRecordDTO {
    /// Create DTO from Core Data PregnancyRecord entity
    init(from record: PregnancyRecord) {
        self.id = record.id ?? UUID()
        self.damId = record.cow?.id ?? UUID()  // iOS uses "cow", DB uses "dam"
        self.sireId = record.bull?.id  // iOS uses "bull", DB uses "sire"
        self.farmId = record.farmId
        // Sync both range dates and single dates (use date-only format to avoid timezone shifts)
        self.breedingStartDate = record.breedingStartDate?.toDateOnlyString()
        self.breedingEndDate = record.breedingEndDate?.toDateOnlyString()
        self.breedingDate = record.breedingDate?.toDateOnlyString()
        self.expectedCalvingStartDate = record.expectedCalvingStartDate?.toDateOnlyString()
        self.expectedCalvingEndDate = record.expectedCalvingEndDate?.toDateOnlyString()
        self.expectedCalvingDate = record.expectedCalvingDate?.toDateOnlyString()
        self.pregnancyStatus = record.status ?? "bred"  // iOS uses "status", DB uses "status"
        self.breedingMethod = record.breedingMethod
        self.aiTechnician = record.aiTechnician
        self.semenSource = record.semenSource
        self.externalBullName = record.externalBullName
        self.externalBullRegistration = record.externalBullRegistration
        self.confirmationMethod = record.confirmationMethod
        self.confirmationDate = record.confirmedDate?.toISO8601String()  // iOS uses "confirmedDate", DB uses "confirmed_date"
        self.notes = record.notes
        self.deletedAt = record.deletedAt?.toISO8601String()
        self.createdAt = record.createdAt?.toISO8601String()
        // Note: iOS Core Data fields not synced: outcome, modifiedAt
    }

    /// Update Core Data entity from DTO
    func update(_ record: PregnancyRecord) {
        print("📝 Updating PregnancyRecord \(self.id)")
        print("   Breeding Start: \(self.breedingStartDate ?? "nil"), Legacy Breeding: \(self.breedingDate ?? "nil")")
        print("   Expected Calving Start: \(self.expectedCalvingStartDate ?? "nil"), Legacy Calving: \(self.expectedCalvingDate ?? "nil")")
        print("   Status: \(self.pregnancyStatus ?? "nil")")

        record.id = self.id
        // cow (dam) and bull (sire) relationships handled separately
        record.farmId = self.farmId

        // Handle breeding dates with fallback to legacy single date
        if let breedingStart = self.breedingStartDate {
            // Use new range-based dates
            record.breedingStartDate = breedingStart.toDate()
            record.breedingEndDate = self.breedingEndDate?.toDate()
            record.breedingDate = breedingStart.toDate() // For backwards compatibility
        } else if let legacyBreedingDate = self.breedingDate {
            // Fall back to legacy single date
            let parsedDate = legacyBreedingDate.toDate()
            record.breedingDate = parsedDate
            record.breedingStartDate = parsedDate
            record.breedingEndDate = nil
            print("   ⬆️ Using legacy breeding_date as fallback")
        } else {
            record.breedingStartDate = nil
            record.breedingEndDate = nil
            record.breedingDate = nil
        }

        // Handle calving dates with fallback to legacy single date
        if let calvingStart = self.expectedCalvingStartDate {
            // Use new range-based dates
            record.expectedCalvingStartDate = calvingStart.toDate()
            record.expectedCalvingEndDate = self.expectedCalvingEndDate?.toDate()
            record.expectedCalvingDate = calvingStart.toDate() // For backwards compatibility
        } else if let legacyCalvingDate = self.expectedCalvingDate {
            // Fall back to legacy single date
            let parsedDate = legacyCalvingDate.toDate()
            record.expectedCalvingDate = parsedDate
            record.expectedCalvingStartDate = parsedDate
            record.expectedCalvingEndDate = nil
            print("   ⬆️ Using legacy expected_calving_date as fallback")
        } else {
            record.expectedCalvingStartDate = nil
            record.expectedCalvingEndDate = nil
            record.expectedCalvingDate = nil
        }

        // Normalize status to lowercase (DB might have "Confirmed" but iOS expects "confirmed")
        let normalizedStatus = self.pregnancyStatus?.lowercased() ?? "bred"
        record.status = normalizedStatus

        // Set breeding method and AI details
        record.breedingMethod = self.breedingMethod
        record.aiTechnician = self.aiTechnician
        record.semenSource = self.semenSource
        record.externalBullName = self.externalBullName
        record.externalBullRegistration = self.externalBullRegistration

        record.confirmationMethod = self.confirmationMethod
        record.confirmedDate = self.confirmationDate?.toDate()
        record.notes = self.notes
        record.deletedAt = self.deletedAt?.toDate()
        record.createdAt = self.createdAt?.toDate()
        // Note: outcome, modifiedAt not in DB

        print("   ✅ Final breedingDate: \(record.breedingDate?.description ?? "nil")")
        print("   ✅ Final expectedCalvingDate: \(record.expectedCalvingDate?.description ?? "nil")")
        print("   ✅ Status: \(normalizedStatus)")
        print("   ✅ Breeding Method: \(self.breedingMethod ?? "nil")")
        print("   ✅ External Bull: \(self.externalBullName ?? "nil")")
    }
}
