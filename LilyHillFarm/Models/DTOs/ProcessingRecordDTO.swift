//
//  ProcessingRecordDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Processing Records with Supabase
//

import Foundation

/// DTO for syncing processing record data with Supabase
struct ProcessingRecordDTO: Codable {
    let id: UUID
    let cattleId: UUID
    let farmId: UUID?
    let processingDate: String?
    let processor: String?
    let liveWeight: Double?
    let hangingWeight: Double?
    let processingCost: Double?
    let dressPercentage: Double?
    let notes: String?
    let deletedAt: String?
    let createdAt: String?
    let updatedAt: String?  // Added to match Supabase schema

    enum CodingKeys: String, CodingKey {
        case id
        case cattleId = "cattle_id"
        case farmId = "farm_id"
        case processingDate = "processing_date"
        case processor
        case liveWeight = "live_weight"
        case hangingWeight = "hanging_weight"
        case processingCost = "processing_cost"
        case dressPercentage = "dress_percentage"
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"  // Added to match Supabase schema
    }
}

extension ProcessingRecordDTO {
    /// Create DTO from Core Data ProcessingRecord entity
    init(from record: ProcessingRecord) {
        self.id = record.id ?? UUID()
        self.cattleId = record.cattle?.id ?? UUID()
        self.farmId = record.farmId
        self.processingDate = record.processingDate?.toISO8601String()
        self.processor = record.processor
        self.liveWeight = record.liveWeight?.doubleValue
        self.hangingWeight = record.hangingWeight?.doubleValue
        self.processingCost = record.processingCost?.doubleValue
        self.dressPercentage = record.dressPercentage?.doubleValue
        self.notes = record.notes
        self.deletedAt = record.deletedAt?.toISO8601String()
        self.createdAt = record.createdAt?.toISO8601String()
        self.updatedAt = Date().toISO8601String()  // Use current time for updates
    }

    /// Update Core Data entity from DTO
    func update(_ record: ProcessingRecord) {
        record.id = self.id
        // cattle relationship handled separately
        record.farmId = self.farmId
        record.processingDate = self.processingDate?.toDate()
        record.processor = self.processor
        record.liveWeight = self.liveWeight.map { NSDecimalNumber(value: $0) }
        record.hangingWeight = self.hangingWeight.map { NSDecimalNumber(value: $0) }
        record.processingCost = self.processingCost.map { NSDecimalNumber(value: $0) }
        record.dressPercentage = self.dressPercentage.map { NSDecimalNumber(value: $0) }
        record.notes = self.notes
        record.deletedAt = self.deletedAt?.toDate()
        record.createdAt = self.createdAt?.toDate()
    }
}
