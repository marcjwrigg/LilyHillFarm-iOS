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
import CoreData

@MainActor
class TasksViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared
    private let context: NSManagedObjectContext
    private let taskRepository: TaskRepository
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        self.taskRepository = TaskRepository(context: context)

        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadTasksFromCoreData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Tasks

    func loadTasks() async {
        isLoading = true
        errorMessage = nil

        do {
            // First, sync from Supabase to Core Data
            print("🔄 Syncing tasks from Supabase to Core Data")
            try await taskRepository.syncFromSupabase()

            // Then load from Core Data
            await loadTasksFromCoreData()

            print("✅ Tasks loaded and synced successfully")

        } catch {
            print("❌ Failed to load tasks: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadTasksFromCoreData() async {
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()

        // Sort by due date and priority
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "priority", ascending: false)
        ]

        // Filter out soft-deleted tasks
        fetchRequest.predicate = NSPredicate(format: "deletedAt == nil")

        do {
            let coreDataTasks = try context.fetch(fetchRequest)
            self.tasks = coreDataTasks.map { TaskItem(from: $0) }

            print("📊 Loaded \(self.tasks.count) tasks from Core Data")
            print("  - Pending: \(self.tasks.filter { $0.status == "pending" }.count)")
            print("  - In Progress: \(self.tasks.filter { $0.status == "in_progress" }.count)")
            print("  - Completed: \(self.tasks.filter { $0.status == "completed" }.count)")

        } catch {
            print("❌ Failed to load tasks from Core Data: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create Task

    func createTask(_ task: TaskItem) async {
        do {
            // Create in Core Data first
            let newTask = Task(context: context)
            newTask.id = task.id
            newTask.title = task.title
            newTask.taskDescription = task.description
            newTask.taskType = task.category
            newTask.priority = task.priority
            newTask.status = task.status
            newTask.dueDate = task.dueDate
            newTask.completedAt = task.completedAt
            newTask.createdAt = task.createdAt
            newTask.updatedAt = Date()
            newTask.syncStatus = "pending"

            // Resolve cattle relationship if provided
            if let cattleId = task.relatedCattleId {
                let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                if let cattle = try? context.fetch(cattleFetch).first {
                    newTask.cattle = cattle
                }
            }

            // Save to Core Data
            try context.save()
            print("✅ Task created in Core Data: \(task.title)")

            // AutoSyncService will automatically detect and sync to Supabase

        } catch {
            print("❌ Failed to create task: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Task

    func toggleTaskCompletion(_ task: TaskItem) async {
        do {
            // Fetch from Core Data
            let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataTask = try context.fetch(fetchRequest).first else {
                throw RepositoryError.notFound
            }

            // Toggle completion
            let newStatus = task.isCompleted ? "pending" : "completed"
            coreDataTask.status = newStatus
            coreDataTask.completedAt = newStatus == "completed" ? Date() : nil
            coreDataTask.updatedAt = Date()
            coreDataTask.syncStatus = "pending"

            // Save to Core Data
            try context.save()
            print("✅ Task completion toggled in Core Data: \(task.title)")

            // AutoSyncService will automatically detect and sync to Supabase

        } catch {
            print("❌ Failed to update task: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Task

    func deleteTask(_ task: TaskItem) async {
        do {
            // Fetch from Core Data
            let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataTask = try context.fetch(fetchRequest).first else {
                throw RepositoryError.notFound
            }

            // Soft delete by setting deletedAt
            coreDataTask.deletedAt = Date()
            coreDataTask.updatedAt = Date()
            coreDataTask.syncStatus = "pending"

            // Save to Core Data
            try context.save()
            print("✅ Task soft-deleted in Core Data: \(task.title)")

            // AutoSyncService will automatically detect and sync to Supabase

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
