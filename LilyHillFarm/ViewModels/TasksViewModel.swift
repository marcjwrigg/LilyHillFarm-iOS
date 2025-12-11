//
//  TasksViewModel.swift
//  LilyHillFarm
//
//  View model for managing tasks
//

import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
class TasksViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared

    // MARK: - Load Tasks

    func loadTasks() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let userId = supabase.userId else {
                throw RepositoryError.notAuthenticated
            }

            print("🔄 Loading all tasks for authenticated user: \(userId)")

            // Load ALL tasks for authenticated users (not filtered by user_id or assigned_to)
            let taskDTOs: [TaskDTO] = try await supabase.client
                .from(SupabaseConfig.Tables.tasks)
                .select()
                .order("due_date", ascending: true)
                .order("priority", ascending: false)
                .execute()
                .value

            print("✅ Loaded \(taskDTOs.count) total tasks from Supabase")

            // Fetch related cattle data (matching web app logic)
            let cattleIds = Set(taskDTOs.compactMap { $0.relatedCattleId })

            var cattleMap: [UUID: (id: UUID, tagNumber: String, name: String?)] = [:]

            if !cattleIds.isEmpty {
                print("🔄 Fetching cattle data for \(cattleIds.count) cattle...")

                struct CattleData: Decodable {
                    let id: UUID
                    let tagNumber: String
                    let name: String?

                    enum CodingKeys: String, CodingKey {
                        case id
                        case tagNumber = "tag_number"
                        case name
                    }
                }

                let cattleData: [CattleData] = try await supabase.client
                    .from(SupabaseConfig.Tables.cattle)
                    .select("id, tag_number, name")
                    .in("id", values: cattleIds.map { $0.uuidString })
                    .execute()
                    .value

                cattleMap = Dictionary(uniqueKeysWithValues: cattleData.map {
                    ($0.id, (id: $0.id, tagNumber: $0.tagNumber, name: $0.name))
                })

                print("✅ Fetched cattle data for \(cattleData.count) cattle")
            }

            // Map tasks with cattle tags
            self.tasks = taskDTOs.map { dto in
                var item = TaskItem(from: dto)
                if let relatedCattleId = dto.relatedCattleId, let cattle = cattleMap[relatedCattleId] {
                    item.cattleTag = cattle.tagNumber
                }
                return item
            }

            print("✅ Tasks loaded and mapped successfully")
            print("📊 Task breakdown by status:")
            print("  - Pending: \(self.tasks.filter { $0.status == "pending" }.count)")
            print("  - In Progress: \(self.tasks.filter { $0.status == "in_progress" }.count)")
            print("  - Completed: \(self.tasks.filter { $0.status == "completed" }.count)")
            print("  - Other: \(self.tasks.filter { $0.status != "pending" && $0.status != "in_progress" && $0.status != "completed" }.count)")

            // Log the 5 most recent tasks
            let recentTasks = self.tasks.sorted { ($0.createdAt) > ($1.createdAt) }.prefix(5)
            print("📋 5 most recent tasks:")
            for task in recentTasks {
                print("  - [\(task.status)] \(task.title) (created: \(task.createdAt))")
            }

        } catch {
            print("❌ Failed to load tasks: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create Task

    func createTask(_ task: TaskItem) async {
        do {
            // Get farmId from farm_users table
            guard let userId = supabase.userId else {
                throw RepositoryError.notAuthenticated
            }

            struct FarmUser: Codable {
                let farm_id: UUID
            }

            let farmUsers: [FarmUser] = try await supabase.client
                .from("farm_users")
                .select("farm_id")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let farmId = farmUsers.first?.farm_id else {
                throw RepositoryError.syncFailed("No farm found for user")
            }

            let dto = TaskDTO(
                id: task.id,
                farmId: farmId,
                title: task.title,
                description: task.description,
                category: task.category,
                priority: task.priority,
                status: task.status,
                dueDate: task.dueDate?.toISO8601String(),
                assignedToUserId: nil,
                relatedCattleId: task.relatedCattleId,
                completedAt: task.completedAt?.toISO8601String(),
                deletedAt: nil,
                createdAt: task.createdAt.toISO8601String(),
                updatedAt: task.createdAt.toISO8601String()
            )

            let created: TaskDTO = try await supabase.client
                .from(SupabaseConfig.Tables.tasks)
                .insert(dto)
                .select()
                .single()
                .execute()
                .value

            tasks.append(TaskItem(from: created))

        } catch {
            print("❌ Failed to create task: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Task

    func toggleTaskCompletion(_ task: TaskItem) async {
        do {
            let newStatus = task.isCompleted ? "pending" : "completed"
            let completedAt = newStatus == "completed" ? Date().toISO8601String() : nil

            struct TaskUpdate: Encodable {
                let status: String
                let completedAt: String?
                let updatedAt: String

                enum CodingKeys: String, CodingKey {
                    case status
                    case completedAt = "completed_at"
                    case updatedAt = "updated_at"
                }
            }

            let update = TaskUpdate(
                status: newStatus,
                completedAt: completedAt,
                updatedAt: Date().toISO8601String()
            )

            try await supabase.client
                .from(SupabaseConfig.Tables.tasks)
                .update(update)
                .eq("id", value: task.id.uuidString)
                .execute()

            // Update local task
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].status = newStatus
                tasks[index].completedAt = newStatus == "completed" ? Date() : nil
            }

        } catch {
            print("❌ Failed to update task: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Task

    func deleteTask(_ task: TaskItem) async {
        do {
            try await supabase.client
                .from(SupabaseConfig.Tables.tasks)
                .delete()
                .eq("id", value: task.id.uuidString)
                .execute()

            tasks.removeAll { $0.id == task.id }

        } catch {
            print("❌ Failed to delete task: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filtering

    func filteredTasks(for filter: TaskFilter) -> [TaskItem] {
        switch filter {
        case .open:
            // Show all non-completed tasks (pending + in_progress)
            return tasks.filter { $0.status != "completed" }
        case .pending:
            return tasks.filter { $0.status == "pending" }
        case .inProgress:
            return tasks.filter { $0.status == "in_progress" }
        case .completed:
            return tasks.filter { $0.status == "completed" }
        }
    }

    // MARK: - Statistics

    var overdueCount: Int {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < Date() && !task.isCompleted
        }.count
    }

    var completionRate: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(tasks.count)
    }
}

// MARK: - Task Item Model

struct TaskItem: Identifiable {
    let id: UUID
    var title: String
    var description: String?
    var category: String  // DB uses "category", iOS uses "taskType"
    var priority: String
    var status: String
    var dueDate: Date?
    var relatedCattleId: UUID?  // DB uses "related_cattle_id"
    var cattleTag: String? // Mutable to allow setting from cattle lookup
    var completedAt: Date?
    let createdAt: Date

    // Convenience computed property for backwards compatibility
    var taskType: String {
        get { category }
        set { category = newValue }
    }

    var cattleId: UUID? {
        get { relatedCattleId }
        set { relatedCattleId = newValue }
    }

    var isCompleted: Bool {
        status == "completed"
    }

    var typeIcon: String {
        TaskType(rawValue: taskType)?.icon ?? "checklist"
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        taskType: String,
        priority: String,
        status: String,
        dueDate: Date? = nil,
        cattleId: UUID? = nil,
        cattleTag: String? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = taskType
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.relatedCattleId = cattleId
        self.cattleTag = cattleTag
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    init(from dto: TaskDTO) {
        self.id = dto.id
        self.title = dto.title
        self.description = dto.description
        self.category = dto.category
        self.priority = dto.priority
        self.status = dto.status
        self.dueDate = dto.dueDate?.toDate()
        self.relatedCattleId = dto.relatedCattleId
        self.cattleTag = nil // Fetched separately
        self.completedAt = dto.completedAt?.toDate()
        self.createdAt = dto.createdAt.toDate() ?? Date()
    }

    init(from task: Task) {
        self.id = task.id ?? UUID()
        self.title = task.title ?? "Untitled"
        self.description = task.taskDescription
        self.category = task.taskType ?? "general"
        self.priority = task.priority ?? "medium"
        self.status = task.status ?? "pending"
        self.dueDate = task.dueDate
        self.relatedCattleId = task.cattle?.id
        self.cattleTag = task.cattle?.tagNumber
        self.completedAt = task.completedAt
        self.createdAt = task.createdAt ?? Date()
    }
}
