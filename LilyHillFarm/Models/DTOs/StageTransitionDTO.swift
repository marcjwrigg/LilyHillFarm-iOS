//
//  StageTransitionDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Stage Transitions with Supabase
//

import Foundation

/// DTO for syncing stage transition data with Supabase
struct StageTransitionDTO: Codable {
    let id: UUID
    let cattleId: UUID
    let farmId: UUID?
    let fromStage: String?
    let toStage: String?
    let transitionDate: String?
    let weightAtTransition: Double?
    let notes: String?
    let deletedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cattleId = "cattle_id"
        case farmId = "farm_id"
        case fromStage = "from_stage"
        case toStage = "to_stage"
        case transitionDate = "transition_date"
        case weightAtTransition = "weight_at_transition"
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

extension StageTransitionDTO {
    /// Create DTO from Core Data StageTransition entity
    init(from transition: StageTransition) {
        self.id = transition.id ?? UUID()
        self.cattleId = transition.cattle?.id ?? UUID()
        self.farmId = transition.farmId
        self.fromStage = transition.fromStage
        self.toStage = transition.toStage ?? ""
        self.transitionDate = transition.transitionDate?.toISO8601String()
        self.weightAtTransition = transition.weight?.doubleValue
        self.notes = transition.notes
        self.deletedAt = transition.deletedAt?.toISO8601String()
        self.createdAt = transition.createdAt?.toISO8601String()
    }

    /// Update Core Data entity from DTO
    func update(_ transition: StageTransition) {
        transition.id = self.id
        // cattle relationship handled separately
        transition.farmId = self.farmId
        transition.fromStage = self.fromStage
        transition.toStage = self.toStage ?? ""
        transition.transitionDate = self.transitionDate?.toDate()
        transition.weight = self.weightAtTransition.map { NSDecimalNumber(value: $0) }
        transition.notes = self.notes
        transition.deletedAt = self.deletedAt?.toDate()
        transition.createdAt = self.createdAt?.toDate()
    }
}
