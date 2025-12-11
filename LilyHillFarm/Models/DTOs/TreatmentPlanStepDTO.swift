//
//  TreatmentPlanStepDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Treatment Plan Steps with Supabase
//

import Foundation

/// DTO for syncing treatment plan step data with Supabase
struct TreatmentPlanStepDTO: Codable {
    let id: UUID
    let treatmentPlanId: UUID
    let stepNumber: Int
    let dayNumber: Int
    let title: String
    let description: String?
    let medication: String?
    let dosage: String?
    let administrationMethod: String?
    let notes: String?
    let deletedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case treatmentPlanId = "treatment_plan_id"
        case stepNumber = "step_number"
        case dayNumber = "day_number"
        case title
        case description
        case medication
        case dosage
        case administrationMethod = "administration_method"
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

extension TreatmentPlanStepDTO {
    /// Create DTO from Core Data TreatmentPlanStep entity
    init(from step: TreatmentPlanStep) {
        self.id = step.id ?? UUID()
        self.treatmentPlanId = step.treatmentPlan?.id ?? UUID()
        self.stepNumber = Int(step.stepNumber)
        self.dayNumber = Int(step.dayNumber)
        self.title = step.title ?? ""
        self.description = step.stepDescription
        self.medication = step.medication
        self.dosage = step.dosage
        self.administrationMethod = step.administrationMethod
        self.notes = step.notes
        self.deletedAt = step.deletedAt?.toISO8601String()
        self.createdAt = step.createdAt?.toISO8601String()
    }

    /// Update Core Data entity from DTO
    func update(_ step: TreatmentPlanStep) {
        step.id = self.id
        // treatmentPlan relationship handled separately
        step.stepNumber = Int32(self.stepNumber)
        step.dayNumber = Int32(self.dayNumber)
        step.title = self.title
        step.stepDescription = self.description
        step.medication = self.medication
        step.dosage = self.dosage
        step.administrationMethod = self.administrationMethod
        step.notes = self.notes
        step.deletedAt = self.deletedAt?.toDate()
        step.createdAt = self.createdAt?.toDate()
    }
}
