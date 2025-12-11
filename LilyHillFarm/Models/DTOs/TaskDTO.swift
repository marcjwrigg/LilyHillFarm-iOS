//
//  TaskDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Tasks with Supabase
//

import Foundation

/// DTO for syncing task data with Supabase
struct TaskDTO: Codable {
    let id: UUID
    let farmId: UUID?  // Optional since database migration may have NULL values
    let title: String
    let description: String?
    let category: String
    let priority: String
    let status: String
    let dueDate: String?
    let assignedToUserId: UUID?
    let relatedCattleId: UUID?
    let completedAt: String?
    let deletedAt: String?  // For soft delete sync
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case farmId = "farm_id"
        case title
        case description
        case category
        case priority
        case status
        case dueDate = "due_date"
        case assignedToUserId = "assigned_to_user_id"
        case relatedCattleId = "related_cattle_id"
        case completedAt = "completed_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer (required since we have a custom decoder)
    init(
        id: UUID,
        farmId: UUID?,
        title: String,
        description: String?,
        category: String,
        priority: String,
        status: String,
        dueDate: String?,
        assignedToUserId: UUID?,
        relatedCattleId: UUID?,
        completedAt: String?,
        deletedAt: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.farmId = farmId
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.assignedToUserId = assignedToUserId
        self.relatedCattleId = relatedCattleId
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom decoder to handle both "category" (new) and "task_type" (old) column names
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UUID.self, forKey: .id)
        self.farmId = try? container.decodeIfPresent(UUID.self, forKey: .farmId)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)

        // Try "category" first, fall back to "task_type" for old records
        if let category = try? container.decode(String.self, forKey: .category) {
            self.category = category
        } else {
            // Try old "task_type" column name
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            self.category = try legacyContainer.decode(String.self, forKey: .taskType)
        }

        self.priority = try container.decode(String.self, forKey: .priority)
        self.status = try container.decode(String.self, forKey: .status)
        self.dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        self.assignedToUserId = try container.decodeIfPresent(UUID.self, forKey: .assignedToUserId)
        self.relatedCattleId = try container.decodeIfPresent(UUID.self, forKey: .relatedCattleId)
        self.completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        self.deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    // Legacy coding keys for old database schema
    private enum LegacyCodingKeys: String, CodingKey {
        case taskType = "task_type"
    }
}

// MARK: - Core Data Conversion

extension TaskDTO {
    /// Initialize from Core Data Task entity
    init(from task: Task, farmId: UUID) {
        self.id = task.id ?? UUID()
        self.farmId = farmId
        self.title = task.title ?? ""
        self.description = task.taskDescription
        self.category = task.taskType ?? "general"  // iOS uses "taskType", DB uses "category"
        self.priority = task.priority ?? "medium"
        self.status = task.status ?? "pending"
        self.dueDate = task.dueDate?.toISO8601String()
        self.assignedToUserId = task.assignedToId
        self.relatedCattleId = task.cattle?.id
        self.completedAt = task.completedAt?.toISO8601String()
        self.deletedAt = task.deletedAt?.toISO8601String()
        self.createdAt = (task.createdAt ?? Date()).toISO8601String()
        self.updatedAt = (task.updatedAt ?? Date()).toISO8601String()
        // Note: iOS Core Data fields not synced: healthRecord, completedById, notes
    }

    /// Update Core Data Task entity from DTO
    func update(_ task: Task) {
        task.id = self.id
        task.farmId = self.farmId
        task.title = self.title
        task.taskDescription = self.description
        task.taskType = self.category  // DB uses "category", iOS uses "taskType"
        task.priority = self.priority
        task.status = self.status
        task.dueDate = self.dueDate?.toDate()
        task.assignedToId = self.assignedToUserId
        task.completedAt = self.completedAt?.toDate()
        task.deletedAt = self.deletedAt?.toDate()
        task.createdAt = self.createdAt.toDate()
        task.updatedAt = self.updatedAt.toDate()

        // Note: cattle and healthRecord relationships are not updated here
        // They should be managed separately through their IDs
        // completedById and notes not in DB
    }
}

