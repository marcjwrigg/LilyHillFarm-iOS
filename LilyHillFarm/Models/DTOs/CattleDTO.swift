//
//  CattleDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Cattle with Supabase
//

import Foundation

/// DTO for syncing cattle data with Supabase
struct CattleDTO: Codable {
    let id: UUID
    let userId: UUID?  // Optional since database moved to farm_id (may be NULL)
    let farmId: UUID
    let tagNumber: String
    let name: String?
    let sex: String?
    let cattleType: String?
    let dateOfBirth: String?
    let approximateAge: String?
    // let birthWeight: Double?  // Column doesn't exist in Supabase - commented out
    let color: String?
    let markings: String?
    let registrationNumber: String?
    let currentWeight: Double?
    let purchaseDate: String?
    let purchasePrice: Double?
    let purchaseWeight: Double?
    let purchaseType: String?
    let purchasedFrom: String?
    let currentStatus: String?
    let currentStage: String?
    let productionPath: String?
    let weaningDate: String?
    let weaningWeight: Double?
    let finishingStartDate: String?
    let processingDate: String?
    let estimatedProcessingDate: String?
    let exitReason: String?
    let exitDate: String?
    let salePrice: Double?
    let notes: String?
    let tags: String?  // Changed from [String]? to String? to match Supabase schema
    let location: [String]?  // Array field in Supabase
    let pastureId: UUID?
    let breedId: UUID?
    let damId: UUID?
    let sireId: UUID?
    let externalSireName: String?
    let externalSireRegistration: String?
    let deletedAt: String?  // For soft delete sync
    let createdAt: String?
    let modifiedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case farmId = "farm_id"
        case tagNumber = "tag_number"
        case name
        case sex
        case cattleType = "cattle_type"
        case dateOfBirth = "date_of_birth"
        case approximateAge = "approximate_age"
        // case birthWeight = "birth_weight"  // Column doesn't exist in Supabase
        case color
        case markings
        case registrationNumber = "registration_number"
        case currentWeight = "current_weight"
        case purchaseDate = "purchase_date"
        case purchasePrice = "purchase_price"
        case purchaseWeight = "purchase_weight"
        case purchaseType = "purchase_type"
        case purchasedFrom = "purchased_from"
        case currentStatus = "current_status"
        case currentStage = "current_stage"
        case productionPath = "production_path"
        case weaningDate = "weaning_date"
        case weaningWeight = "weaning_weight"
        case finishingStartDate = "finishing_start_date"
        case processingDate = "processing_date"
        case estimatedProcessingDate = "estimated_processing_date"
        case exitReason = "exit_reason"
        case exitDate = "exit_date"
        case salePrice = "sale_price"
        case notes
        case tags
        case location
        case pastureId = "pasture_id"
        case breedId = "breed_id"
        case damId = "dam_id"
        case sireId = "sire_id"
        case externalSireName = "external_sire_name"
        case externalSireRegistration = "external_sire_registration"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
    }
}

// MARK: - Core Data Conversion

extension CattleDTO {
    /// Create DTO from Core Data Cattle entity
    init(from cattle: Cattle, userId: UUID, farmId: UUID) {
        self.id = cattle.id ?? UUID()
        self.userId = userId
        self.farmId = farmId
        self.tagNumber = cattle.tagNumber ?? ""
        self.name = cattle.name
        self.sex = cattle.sex ?? ""
        self.cattleType = cattle.cattleType ?? ""
        self.dateOfBirth = cattle.dateOfBirth?.toISO8601String()
        self.approximateAge = cattle.approximateAge
        // self.birthWeight = cattle.birthWeight?.doubleValue  // Column doesn't exist in Supabase
        self.color = cattle.color
        self.markings = cattle.markings
        self.registrationNumber = cattle.registrationNumber
        self.currentWeight = cattle.currentWeight?.doubleValue
        self.purchaseDate = cattle.purchaseDate?.toISO8601String()
        self.purchasePrice = cattle.purchasePrice?.doubleValue
        self.purchaseWeight = cattle.purchaseWeight?.doubleValue
        self.purchaseType = cattle.purchaseType
        self.purchasedFrom = cattle.purchasedFrom
        self.currentStatus = cattle.currentStatus ?? ""
        self.currentStage = cattle.currentStage ?? ""
        self.productionPath = cattle.productionPath ?? ""
        self.weaningDate = cattle.weaningDate?.toISO8601String()
        self.weaningWeight = cattle.weaningWeight?.doubleValue
        self.finishingStartDate = cattle.finishingStartDate?.toISO8601String()
        self.processingDate = cattle.processingDate?.toISO8601String()
        self.estimatedProcessingDate = cattle.estimatedProcessingDate?.toISO8601String()
        self.exitReason = cattle.exitReason
        self.exitDate = cattle.exitDate?.toISO8601String()
        self.salePrice = cattle.salePrice?.doubleValue
        self.notes = cattle.notes
        self.tags = cattle.tags // Tags is now String? matching Core Data
        self.location = cattle.location as? [String] // Transformable array
        self.pastureId = cattle.pastureId
        self.breedId = cattle.breed?.id
        self.damId = cattle.dam?.id
        self.sireId = cattle.sire?.id
        self.externalSireName = cattle.externalSireName
        self.externalSireRegistration = cattle.externalSireRegistration
        self.deletedAt = cattle.deletedAt?.toISO8601String()
        self.createdAt = cattle.createdAt?.toISO8601String()
        self.modifiedAt = cattle.modifiedAt?.toISO8601String()
    }

    /// Update Core Data entity from DTO
    func update(_ cattle: Cattle) {
        cattle.id = self.id
        // Note: userId is not stored in Core Data, only used for Supabase
        cattle.tagNumber = self.tagNumber
        cattle.name = self.name
        cattle.sex = self.sex ?? "Unknown"
        cattle.cattleType = self.cattleType ?? "Beef"
        cattle.dateOfBirth = self.dateOfBirth?.toDate()
        cattle.approximateAge = self.approximateAge
        // cattle.birthWeight = self.birthWeight.map { NSDecimalNumber(value: $0) }  // Column doesn't exist in Supabase
        cattle.color = self.color
        cattle.markings = self.markings
        cattle.registrationNumber = self.registrationNumber
        cattle.currentWeight = self.currentWeight.map { NSDecimalNumber(value: $0) }
        cattle.purchaseDate = self.purchaseDate?.toDate()
        cattle.purchasePrice = self.purchasePrice.map { NSDecimalNumber(value: $0) }
        cattle.purchaseWeight = self.purchaseWeight.map { NSDecimalNumber(value: $0) }
        cattle.purchaseType = self.purchaseType
        cattle.purchasedFrom = self.purchasedFrom
        cattle.currentStatus = self.currentStatus ?? "Active"
        cattle.currentStage = self.currentStage ?? "Calf"
        cattle.productionPath = self.productionPath ?? "BeefFinishing"
        cattle.weaningDate = self.weaningDate?.toDate()
        cattle.weaningWeight = self.weaningWeight.map { NSDecimalNumber(value: $0) }
        cattle.finishingStartDate = self.finishingStartDate?.toDate()
        cattle.processingDate = self.processingDate?.toDate()
        cattle.estimatedProcessingDate = self.estimatedProcessingDate?.toDate()
        cattle.exitReason = self.exitReason
        cattle.exitDate = self.exitDate?.toDate()
        cattle.salePrice = self.salePrice.map { NSDecimalNumber(value: $0) }
        cattle.notes = self.notes
        cattle.tags = self.tags
        cattle.location = self.location.map { $0 as NSArray }  // Convert [String] to NSArray
        cattle.pastureId = self.pastureId
        cattle.externalSireName = self.externalSireName
        cattle.externalSireRegistration = self.externalSireRegistration
        cattle.farmId = self.farmId
        cattle.deletedAt = self.deletedAt?.toDate()
        cattle.createdAt = self.createdAt?.toDate()
        cattle.modifiedAt = self.modifiedAt?.toDate()

        // Relationships are handled separately
    }
}

