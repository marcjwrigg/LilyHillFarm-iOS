//
//  MedicationDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Medications with Supabase
//

import Foundation

/// DTO for syncing medication data with Supabase
struct MedicationDTO: Codable {
    let id: UUID
    let userId: UUID?
    let farmId: UUID?
    let name: String
    let type: String?
    let manufacturer: String?
    let commonDosage: String?
    let withdrawalPeriod: String?
    let notes: String?
    let isActive: Bool?
    let createdAt: String?
    let modifiedAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case farmId = "farm_id"
        case name
        case type
        case manufacturer
        case commonDosage = "common_dosage"
        case withdrawalPeriod = "withdrawal_period"
        case notes
        case isActive = "is_active"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case updatedAt = "updated_at"
    }
}
