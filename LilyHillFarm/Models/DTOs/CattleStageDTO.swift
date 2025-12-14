//
//  CattleStageDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Cattle Stages with Supabase
//

import Foundation

/// DTO for syncing cattle stage data with Supabase
struct CattleStageDTO: Codable {
    let id: UUID
    let farmId: UUID?
    let name: String
    let displayName: String
    let description: String?
    let color: String?
    let icon: String?
    let sortOrder: Int
    let isSystem: Bool?
    let isActive: Bool?
    let createdAt: String?
    let modifiedAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case farmId = "farm_id"
        case name
        case displayName = "display_name"
        case description
        case color
        case icon
        case sortOrder = "sort_order"
        case isSystem = "is_system"
        case isActive = "is_active"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case updatedAt = "updated_at"
    }
}
