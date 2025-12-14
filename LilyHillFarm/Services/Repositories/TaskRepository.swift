//
//  TaskRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Tasks with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class TaskRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all tasks from Supabase (visible to all authenticated users)
    func fetchAll() async throws -> [TaskDTO] {
        try requireAuth()

        // Fetch all tasks for authenticated users (not filtered by user_id)
        let tasks: [TaskDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.tasks)
            .select()
            .order("due_date", ascending: true)
            .execute()
            .value

        return tasks
    }

    /// Fetch task by ID
    func fetchById(_ id: UUID) async throws -> TaskDTO? {
        try requireAuth()

        let tasks: [TaskDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.tasks)
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value

        return tasks.first
    }

    /// Fetch tasks for specific cattle
    func fetchByCattleId(_ cattleId: UUID) async throws -> [TaskDTO] {
        try requireAuth()

        let tasks: [TaskDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.tasks)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .order("due_date", ascending: true)
            .execute()
            .value

        return tasks
    }

    /// Fetch tasks by status (visible to all authenticated users)
    func fetchByStatus(_ status: String) async throws -> [TaskDTO] {
        try requireAuth()

        let tasks: [TaskDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.tasks)
            .select()
            .eq("status", value: status)
            .order("due_date", ascending: true)
            .execute()
            .value

        return tasks
    }

    // MARK: - Create/Update/Delete

    /// Create new task in Supabase
    func create(_ task: Task) async throws -> TaskDTO {
        try requireAuth()

        guard let userId = userId else {
            throw RepositoryError.notAuthenticated
        }

        let farmId = try await getFarmId()

        let dto = TaskDTO(from: task, farmId: farmId, userId: userId)

        print("📤 TaskRepository.create() - Inserting task:")
        print("  - ID: \(dto.id)")
        print("  - Title: \(dto.title)")
        print("  - Farm ID: \(dto.farmId)")
        print("  - Status: \(dto.status)")
        print("  - Related Cattle ID: \(dto.cattleId?.uuidString ?? "nil" as String)")

        do {
            // Use upsert to handle both insert and update cases
            // This prevents duplicate key errors if the task was already synced
            try await supabase.client
                .from(SupabaseConfig.Tables.tasks)
                .upsert(dto)
                .execute()

            print("✅ TaskRepository.create() - Upsert successful")
            return dto
        } catch {
            print("❌ TaskRepository.create() - Upsert failed: \(error)")
            throw error
        }
    }

    /// Update existing task in Supabase
    func update(_ task: Task) async throws -> TaskDTO {
        try requireAuth()

        guard let id = task.id else {
            throw RepositoryError.invalidData
        }

        guard let userId = userId else {
            throw RepositoryError.notAuthenticated
        }

        let farmId = try await getFarmId()

        let dto = TaskDTO(from: task, farmId: farmId, userId: userId)

        // Update without selecting back to avoid RLS issues
        try await supabase.client
            .from(SupabaseConfig.Tables.tasks)
            .update(dto)
            .eq("id", value: id.uuidString)
            .execute()

        return dto
    }

    /// Delete task from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        try await supabase.client
            .from(SupabaseConfig.Tables.tasks)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Sync

    /// Sync all tasks: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        // Check if we have any local tasks
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deletedAt == nil")
        let localCount = try context.count(for: fetchRequest)

        // If we have 0 local tasks but there's a last sync date, clear it to force full sync
        if localCount == 0 {
            let lastSync = getLastSyncDate(for: SupabaseConfig.Tables.tasks)
            if lastSync != nil {
                print("⚠️ Found 0 local tasks but last sync exists - forcing full sync")
                clearLastSyncDate(for: SupabaseConfig.Tables.tasks)
            }
        }

        try await syncWithDeletions(
            entityType: Task.self,
            tableName: SupabaseConfig.Tables.tasks,
            updateEntity: { (task: Task, dto: Any) in
                guard let dict = dto as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let taskDTO = try? JSONDecoder().decode(TaskDTO.self, from: data) else {
                    throw RepositoryError.invalidData
                }

                // Update from DTO
                taskDTO.update(task)

                // Resolve cattle relationship if cattle_id is present
                if let cattleId = taskDTO.cattleId {
                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                    if let cattle = try self.context.fetch(cattleFetch).first {
                        task.cattle = cattle
                    }
                }
            },
            extractId: { dto in
                guard let dict = dto as? [String: Any],
                      let idString = dict["id"] as? String,
                      let id = UUID(uuidString: idString) else {
                    return UUID()
                }
                return id
            },
            hasFarmId: true
        )
    }

    /// Push local task to Supabase
    func pushToSupabase(_ task: Task) async throws {
        try requireAuth()

        if task.id != nil {
            do {
                // Try to update, if it fails (doesn't exist), create
                _ = try await update(task)
            } catch {
                // If update fails (doesn't exist), create
                _ = try await create(task)
            }
        } else {
            // No ID, must be new - create
            _ = try await create(task)
        }
    }
}
