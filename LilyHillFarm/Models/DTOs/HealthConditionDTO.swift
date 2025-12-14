//
//  HealthConditionDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Health Conditions with Supabase
//

import Foundation

/// DTO for syncing health condition data with Supabase
struct HealthConditionDTO: Codable {
    let id: UUID
    let name: String
    let description: String?
    let isActive: Bool?
    let farmId: UUID?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isActive = "is_active"
        case farmId = "farm_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
