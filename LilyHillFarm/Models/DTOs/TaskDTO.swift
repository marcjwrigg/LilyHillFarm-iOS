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
    let userId: UUID
    let farmId: UUID?  // Optional since database migration may have NULL values
    let title: String
    let description: String?
    let taskType: String
    let priority: String
    let status: String
    let dueDate: String?
    let assignedTo: UUID?
    let cattleIds: [UUID]?  // Database uses array, but iOS only supports single cattle for now
    let completedAt: String?
    let deletedAt: String?  // For soft delete sync
    let createdAt: String
    let updatedAt: String

    // Convenience property for iOS which currently only supports one cattle per task
    var cattleId: UUID? {
        cattleIds?.first
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case farmId = "farm_id"
        case title
        case description
        case taskType = "task_type"
        case priority
        case status
        case dueDate = "due_date"
        case assignedTo = "assigned_to"
        case cattleIds = "cattle_ids"
        case completedAt = "completed_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer (required since we have a custom decoder)
    init(
        id: UUID,
        userId: UUID,
        farmId: UUID?,
        title: String,
        description: String?,
        taskType: String,
        priority: String,
        status: String,
        dueDate: String?,
        assignedTo: UUID?,
        cattleIds: [UUID]?,
        completedAt: String?,
        deletedAt: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.userId = userId
        self.farmId = farmId
        self.title = title
        self.description = description
        self.taskType = taskType
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.assignedTo = assignedTo
        self.cattleIds = cattleIds
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

}

// MARK: - Core Data Conversion

extension TaskDTO {
    /// Initialize from Core Data Task entity
    init(from task: Task, farmId: UUID, userId: UUID) {
        self.id = task.id ?? UUID()
        self.userId = userId
        self.farmId = farmId
        self.title = task.title ?? ""
        self.description = task.taskDescription
        self.taskType = task.taskType ?? "general"
        self.priority = task.priority ?? "medium"
        self.status = task.status ?? "pending"
        self.dueDate = task.dueDate?.toISO8601String()
        self.assignedTo = task.assignedToId
        // Wrap single cattle ID in array for database (which expects UUID[])
        self.cattleIds = task.cattle?.id.map { [$0] }
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
        task.taskType = self.taskType
        task.priority = self.priority
        task.status = self.status
        task.dueDate = self.dueDate?.toDate()
        task.assignedToId = self.assignedTo
        task.completedAt = self.completedAt?.toDate()
        task.deletedAt = self.deletedAt?.toDate()
        task.createdAt = self.createdAt.toDate()
        task.updatedAt = self.updatedAt.toDate()

        // Note: cattle and healthRecord relationships are not updated here
        // They should be managed separately through their IDs
        // completedById and notes not in DB
    }
}

