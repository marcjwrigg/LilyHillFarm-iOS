//
//  HealthRecordDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Health Records with Supabase
//

import Foundation

/// DTO for syncing health record data with Supabase
struct HealthRecordDTO: Codable {
    let id: UUID
    let cattleId: UUID?
    let farmId: UUID?
    let recordDate: String?
    let recordType: String?
    let diagnosis: String?
    let treatment: String?
    let veterinarian: String?
    let medication: String?
    let dosage: String?
    let administrationMethod: String?
    let temperature: Double?
    let weight: Double?
    let cost: Double?
    let notes: String?
    let followUpDate: String?
    let followUpCompleted: Bool?
    let treatmentPlanId: UUID?
    let deletedAt: String?  // For soft delete sync
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cattleId = "cattle_id"
        case farmId = "farm_id"
        case recordDate = "date"  // Database uses "date", iOS uses "recordDate"
        case recordType = "record_type"
        case diagnosis = "condition"  // Database uses "condition", iOS uses "diagnosis"/"condition"
        case treatment
        case veterinarian  // Database uses "veterinarian" (text), not "veterinarian_id"
        case medication
        case dosage
        case administrationMethod = "administration_method"
        case temperature
        case weight
        case cost
        case notes
        case followUpDate = "follow_up_date"
        case followUpCompleted = "follow_up_completed"
        case treatmentPlanId = "treatment_plan_id"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

extension HealthRecordDTO {
    /// Create DTO from Core Data HealthRecord entity
    init(from record: HealthRecord) {
        self.id = record.id ?? UUID()
        self.cattleId = record.cattle?.id
        self.farmId = record.farmId
        self.recordDate = record.date?.toISO8601String()
        self.recordType = record.recordType ?? ""
        self.diagnosis = record.condition  // iOS uses "condition", DB uses "condition"
        self.treatment = record.treatment
        self.veterinarian = record.veterinarian  // DB uses "veterinarian" text field
        self.medication = record.medication
        self.dosage = record.dosage
        self.administrationMethod = record.administrationMethod
        self.temperature = record.temperature?.doubleValue
        self.weight = record.weight?.doubleValue
        self.cost = record.cost?.doubleValue
        self.notes = record.notes
        self.followUpDate = record.followUpDate?.toISO8601String()
        self.followUpCompleted = record.followUpCompleted
        self.treatmentPlanId = record.treatmentPlan?.id
        self.deletedAt = record.deletedAt?.toISO8601String()
        self.createdAt = record.createdAt?.toISO8601String()
    }

    /// Update Core Data entity from DTO
    func update(_ record: HealthRecord) {
        print("📝 Updating HealthRecord \(self.id)")
        print("   Record Date String: \(self.recordDate ?? "nil")")
        print("   Treatment Plan ID from DB: \(self.treatmentPlanId?.uuidString ?? "nil")")

        record.id = self.id
        // cattle relationship handled separately
        record.farmId = self.farmId
        record.date = self.recordDate?.toDate()

        print("   ✅ Parsed Date: \(record.date?.description ?? "nil")")

        record.recordType = self.recordType ?? "General"
        record.condition = self.diagnosis  // DB uses "condition", iOS uses "condition"
        record.treatment = self.treatment
        record.veterinarian = self.veterinarian  // DB uses "veterinarian" text field
        record.medication = self.medication
        record.dosage = self.dosage
        record.administrationMethod = self.administrationMethod
        // treatmentPlan relationship handled in repository after this method
        record.temperature = self.temperature.map { NSDecimalNumber(value: $0) }
        record.weight = self.weight.map { NSDecimalNumber(value: $0) }
        record.cost = self.cost.map { NSDecimalNumber(value: $0) }
        record.notes = self.notes
        record.followUpDate = self.followUpDate?.toDate()
        record.followUpCompleted = self.followUpCompleted ?? false
        record.deletedAt = self.deletedAt?.toDate()
        record.createdAt = self.createdAt?.toDate()
    }
}
