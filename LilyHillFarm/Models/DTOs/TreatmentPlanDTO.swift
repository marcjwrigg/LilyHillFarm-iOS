//
//  TreatmentPlanDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Treatment Plans with Supabase
//

import Foundation

/// DTO for syncing treatment plan data with Supabase
struct TreatmentPlanDTO: Codable {
    let id: UUID
    let farmId: UUID?
    let name: String
    let condition: String
    let description: String?
    let notes: String?
    let deletedAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case farmId = "farm_id"
        case name
        case condition
        case description
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension TreatmentPlanDTO {
    /// Create DTO from Core Data TreatmentPlan entity
    init(from plan: TreatmentPlan, farmId: UUID) {
        self.id = plan.id ?? UUID()
        self.farmId = farmId
        self.name = plan.name ?? ""
        self.condition = plan.condition ?? ""
        self.description = plan.planDescription
        self.notes = plan.notes
        self.deletedAt = plan.deletedAt?.toISO8601String()
        self.createdAt = plan.createdAt?.toISO8601String()
        self.updatedAt = plan.updatedAt?.toISO8601String()
    }

    /// Update Core Data entity from DTO
    func update(_ plan: TreatmentPlan) {
        plan.id = self.id
        plan.name = self.name
        plan.condition = self.condition
        plan.planDescription = self.description
        plan.notes = self.notes
        plan.deletedAt = self.deletedAt?.toDate()
        plan.createdAt = self.createdAt?.toDate()
        plan.updatedAt = self.updatedAt?.toDate()
    }
}
