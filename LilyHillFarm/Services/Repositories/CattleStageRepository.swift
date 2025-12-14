//
//  CattleStageRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Cattle Stages with Supabase
//

import Foundation
internal import CoreData
import Supabase

class CattleStageRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all cattle stages from Supabase for current farm
    func fetchAll() async throws -> [CattleStageDTO] {
        try requireAuth()
        let farmId = try await getFarmId()

        let stages: [CattleStageDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.cattleStages)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("sort_order")
            .execute()
            .value

        return stages
    }

    /// Fetch single cattle stage by ID
    func fetchById(_ id: UUID) async throws -> CattleStageDTO? {
        let stage: CattleStageDTO = try await supabase.client
            .from(SupabaseConfig.Tables.cattleStages)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return stage
    }

    // MARK: - Sync

    /// Sync cattle stages: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching cattle stages from Supabase...")
        let stageDTOs = try await fetchAll()
        print("✅ Fetched \(stageDTOs.count) cattle stages from Supabase")

        // Get farmId BEFORE context.perform
        let farmId = try await getFarmId()

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(stageDTOs.count) cattle stages to Core Data...")

            // Get IDs from Supabase
            let supabaseIds = Set(stageDTOs.map { $0.id })

            // Fetch all local stages for this farm
            let fetchRequest: NSFetchRequest<CattleStage> = CattleStage.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@", farmId as CVarArg)
            let allLocalStages = try self.context.fetch(fetchRequest)

            // Delete stages that exist locally but not in Supabase
            for localStage in allLocalStages {
                guard let localId = localStage.id else {
                    self.context.delete(localStage)
                    continue
                }

                if !supabaseIds.contains(localId) {
                    self.context.delete(localStage)
                    print("   🗑️ Deleted cattle stage \(localStage.name ?? "unknown") (ID: \(localId))")
                }
            }

            // Now sync stages from Supabase
            for dto in stageDTOs {
                let fetchRequest: NSFetchRequest<CattleStage> = CattleStage.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let results = try self.context.fetch(fetchRequest)

                let stage: CattleStage
                if let existing = results.first {
                    stage = existing
                } else {
                    stage = CattleStage(context: self.context)
                }

                // Update from DTO
                dto.update(stage)
            }

            // Only save if there are actual changes
            if self.context.hasChanges {
                print("💾 Saving cattle stages to Core Data...")
                try self.saveContext()
                print("✅ Cattle stages sync completed!")
            } else {
                print("✅ Cattle stages sync completed (no changes needed)")
            }
        }
    }
}
