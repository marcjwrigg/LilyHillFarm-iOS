//
//  StageTransitionRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Stage Transitions with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class StageTransitionRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all stage transitions for current user from Supabase
    func fetchAll() async throws -> [StageTransitionDTO] {
        try requireAuth()

        guard userId != nil else {
            throw RepositoryError.notAuthenticated
        }

        // Fetch all stage transitions
        let records: [StageTransitionDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.stageTransitions)
            .select()
            .order("transition_date", ascending: false)
            .execute()
            .value

        return records
    }

    /// Fetch stage transitions for specific cattle
    func fetchByCattleId(_ cattleId: UUID) async throws -> [StageTransitionDTO] {
        try requireAuth()

        let records: [StageTransitionDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.stageTransitions)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .order("transition_date", ascending: false)
            .execute()
            .value

        return records
    }

    // MARK: - Create/Update/Delete

    /// Create new stage transition in Supabase
    func create(_ transition: StageTransition) async throws -> StageTransitionDTO {
        try requireAuth()

        let dto = StageTransitionDTO(from: transition)

        let created: StageTransitionDTO = try await supabase.client
            .from(SupabaseConfig.Tables.stageTransitions)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing stage transition in Supabase
    func update(_ transition: StageTransition) async throws -> StageTransitionDTO {
        try requireAuth()

        guard let id = transition.id else {
            throw RepositoryError.invalidData
        }

        let dto = StageTransitionDTO(from: transition)

        let updated: StageTransitionDTO = try await supabase.client
            .from(SupabaseConfig.Tables.stageTransitions)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Soft delete stage transition from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.stageTransitions)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<StageTransition> = StageTransition.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let record = try self.context.fetch(fetchRequest).first {
                record.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all stage transitions: fetch from Supabase and update Core Data with deletion support
    func syncFromSupabase() async throws {
        try await syncWithDeletions(
            entityType: StageTransition.self,
            tableName: SupabaseConfig.Tables.stageTransitions,
            updateEntity: { (transition: StageTransition, dto: Any) in
                guard let dict = dto as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let transitionDTO = try? JSONDecoder().decode(StageTransitionDTO.self, from: data) else {
                    throw RepositoryError.invalidData
                }

                // Update from DTO
                transitionDTO.update(transition)

                // Resolve cattle relationship
                let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cattleFetch.predicate = NSPredicate(format: "id == %@", transitionDTO.cattleId as CVarArg)
                if let cattle = try self.context.fetch(cattleFetch).first {
                    transition.cattle = cattle
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
            hasFarmId: false,
            supportsDeletes: false
        )
    }

    /// Push local stage transition to Supabase
    func pushToSupabase(_ transition: StageTransition) async throws {
        try requireAuth()

        if transition.id != nil {
            do {
                // Try to update, if it fails (doesn't exist), create
                _ = try await update(transition)
            } catch {
                // If update fails (doesn't exist), create
                _ = try await create(transition)
            }
        } else {
            // No ID, must be new - create
            _ = try await create(transition)
        }
    }
}
