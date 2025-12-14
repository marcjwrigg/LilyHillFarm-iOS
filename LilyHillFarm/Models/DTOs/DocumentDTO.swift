//
//  DocumentDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Documents with Supabase
//

import Foundation

/// DTO for syncing document data with Supabase
struct DocumentDTO: Codable {
    let id: UUID
    let userId: UUID?
    let farmId: UUID?
    let url: String
    let fileName: String
    let fileType: String?
    let fileSize: Int?
    let documentType: String?
    let title: String?
    let description: String?

    // Related record IDs
    let cattleId: UUID?
    let healthRecordId: UUID?
    let pastureId: UUID?
    let pastureLogId: UUID?
    let taskId: UUID?
    let pregnancyRecordId: UUID?
    let calvingRecordId: UUID?
    let contactId: UUID?
    let saleRecordId: UUID?
    let processingRecordId: UUID?
    let mortalityRecordId: UUID?

    let deletedAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case farmId = "farm_id"
        case url
        case fileName = "file_name"
        case fileType = "file_type"
        case fileSize = "file_size"
        case documentType = "document_type"
        case title
        case description
        case cattleId = "cattle_id"
        case healthRecordId = "health_record_id"
        case pastureId = "pasture_id"
        case pastureLogId = "pasture_log_id"
        case taskId = "task_id"
        case pregnancyRecordId = "pregnancy_record_id"
        case calvingRecordId = "calving_record_id"
        case contactId = "contact_id"
        case saleRecordId = "sale_record_id"
        case processingRecordId = "processing_record_id"
        case mortalityRecordId = "mortality_record_id"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
