//
//  HealthRecordTypeDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Health Record Types with Supabase
//

import Foundation

/// DTO for syncing health record type data with Supabase
struct HealthRecordTypeDTO: Codable {
    let id: UUID
    let name: String
    let description: String?
    let icon: String?
    let color: String?
    let isActive: Bool?
    let farmId: UUID?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case icon
        case color
        case isActive = "is_active"
        case farmId = "farm_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
