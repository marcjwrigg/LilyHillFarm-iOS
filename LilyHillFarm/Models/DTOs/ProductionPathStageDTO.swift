//
//  ProductionPathStageDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Production Path Stages with Supabase
//

import Foundation

/// DTO for syncing production path stage data with Supabase
struct ProductionPathStageDTO: Codable {
    let id: UUID
    let farmId: UUID?
    let productionPathId: UUID
    let stageId: UUID
    let stageOrder: Int
    let isOptional: Bool?
    let minDays: Int?
    let maxDays: Int?
    let targetWeightMin: Double?
    let targetWeightMax: Double?
    let notes: String?
    let createdAt: String?
    let modifiedAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case farmId = "farm_id"
        case productionPathId = "production_path_id"
        case stageId = "stage_id"
        case stageOrder = "stage_order"
        case isOptional = "is_optional"
        case minDays = "min_days"
        case maxDays = "max_days"
        case targetWeightMin = "target_weight_min"
        case targetWeightMax = "target_weight_max"
        case notes
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case updatedAt = "updated_at"
    }
}
