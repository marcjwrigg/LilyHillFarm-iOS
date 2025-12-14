//
//  CattleRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Cattle with Supabase
//

import Foundation
internal import CoreData
import Supabase

class CattleRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all cattle for current user from Supabase
    func fetchAll() async throws -> [CattleDTO] {
        try requireAuth()

        let farmId = try await getFarmId()

        let cattle: [CattleDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("tag_number")
            .execute()
            .value

        return cattle
    }

    /// Fetch single cattle by ID
    func fetchById(_ id: UUID) async throws -> CattleDTO? {
        try requireAuth()

        let cattle: CattleDTO = try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return cattle
    }

    // MARK: - Create/Update/Delete

    /// Create new cattle in Supabase
    func create(_ cattle: Cattle) async throws -> CattleDTO {
        try requireAuth()

        guard let userId = userId else {
            throw RepositoryError.notAuthenticated
        }

        let farmId = try await getFarmId()
        let dto = CattleDTO(from: cattle, userId: userId, farmId: farmId)

        let created: CattleDTO = try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing cattle in Supabase
    func update(_ cattle: Cattle) async throws -> CattleDTO {
        try requireAuth()

        guard let userId = userId else {
            throw RepositoryError.notAuthenticated
        }

        guard let id = cattle.id else {
            throw RepositoryError.invalidData
        }

        let farmId = try await getFarmId()
        let dto = CattleDTO(from: cattle, userId: userId, farmId: farmId)

        // Update without fetching back (avoids PGRST116 error)
        try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .update(dto)
            .eq("id", value: id.uuidString)
            .execute()

        return dto
    }

    /// Delete cattle from Supabase (soft delete)
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server by setting deleted_at
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            if let cattle = try self.context.fetch(fetchRequest).first {
                cattle.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all cattle with deletion support: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        try requireAuth()

        let farmId = try await getFarmId()
        let lastSync = getLastSyncDate(for: SupabaseConfig.Tables.cattle) ?? Date.distantPast

        print("🔄 Syncing cattle with deletion support...")
        print("   Last sync: \(lastSync)")
        print("   Farm ID: \(farmId)")

        // 1. Fetch CHANGED/NEW cattle from Supabase (modified since last sync)
        print("   📥 Fetching cattle modified since \(lastSync)...")
        let activeRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .is("deleted_at", value: nil)
            .gte("updated_at", value: lastSync.ISO8601Format())
            .execute()
            .data

        let decoder = JSONDecoder()
        let cattleDTOs = try decoder.decode([CattleDTO].self, from: activeRecordsData)
        print("   ✅ Fetched \(cattleDTOs.count) modified/new cattle")

        // 2. Fetch records deleted since last sync
        print("   📥 Fetching deleted records...")
        let deletedRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .select("id, deleted_at")
            .eq("farm_id", value: farmId.uuidString)
            .gt("deleted_at", value: lastSync.ISO8601Format())
            .execute()
            .data

        let deletedRecords = try decoder.decode([DeletedRecord].self, from: deletedRecordsData)
        print("   ✅ Found \(deletedRecords.count) deleted records")

        // 3. Update Core Data
        try await context.perform { [weak self] in
            guard let self = self else { return }

            // Get local active cattle IDs for orphan detection
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Cattle")
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["id"]
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)

            let localRecords = try self.context.fetch(fetchRequest) as! [[String: Any]]
            let localIdSet = Set(localRecords.compactMap { $0["id"] as? UUID })
            print("   📊 Found \(localIdSet.count) local active cattle")

            // 4. First pass: Create/update all cattle without relationships
            print("   💾 Updating \(cattleDTOs.count) cattle...")
            for dto in cattleDTOs {
                let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                let cattle: Cattle
                if let existing = try self.context.fetch(fetchRequest).first {
                    cattle = existing
                } else {
                    cattle = Cattle(context: self.context)
                }

                dto.update(cattle)
            }

            // 5. Second pass: Resolve relationships
            print("   🔗 Resolving relationships...")
            for dto in cattleDTOs {
                let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                guard let cattle = try self.context.fetch(fetchRequest).first else { continue }

                // Resolve breed relationship
                if let breedId = dto.breedId {
                    let breedFetch: NSFetchRequest<Breed> = Breed.fetchRequest()
                    breedFetch.predicate = NSPredicate(format: "id == %@", breedId as CVarArg)
                    cattle.breed = try self.context.fetch(breedFetch).first
                }

                // Resolve dam relationship
                if let damId = dto.damId {
                    let damFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    damFetch.predicate = NSPredicate(format: "id == %@", damId as CVarArg)
                    cattle.dam = try self.context.fetch(damFetch).first
                }

                // Resolve sire relationship
                if let sireId = dto.sireId {
                    let sireFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    sireFetch.predicate = NSPredicate(format: "id == %@", sireId as CVarArg)
                    cattle.sire = try self.context.fetch(sireFetch).first
                }
            }

            // 6. Soft delete records that were deleted on server
            print("   🗑️ Marking \(deletedRecords.count) records as deleted...")
            for deletedRecord in deletedRecords {
                let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", deletedRecord.id as CVarArg)

                if let cattle = try self.context.fetch(fetchRequest).first {
                    cattle.deletedAt = Date()
                }
            }

            // 7. Handle orphaned records ONLY during full sync (when lastSync is distantPast)
            // During incremental sync, we can't determine orphans because we only fetched changed records
            if lastSync == Date.distantPast {
                let serverIdSet = Set(cattleDTOs.map { $0.id })
                let deletedIdSet = Set(deletedRecords.map { $0.id })
                let orphanedIds = localIdSet.subtracting(serverIdSet).subtracting(deletedIdSet)

                if !orphanedIds.isEmpty {
                    print("   ⚠️ Found \(orphanedIds.count) orphaned cattle to hard delete (full sync only)")
                    for orphanedId in orphanedIds {
                        let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id == %@", orphanedId as CVarArg)

                        if let cattle = try self.context.fetch(fetchRequest).first {
                            self.context.delete(cattle)
                            print("   🗑️ Hard deleted cattle \(orphanedId)")
                        }
                    }
                }
            } else {
                print("   ℹ️ Skipping orphan detection (incremental sync)")
            }

            // 8. Save changes
            print("   💾 Saving Core Data context...")
            try self.saveContext()
            print("   ✅ Cattle sync completed!")
        }

        // 9. Update last sync timestamp
        setLastSyncDate(Date(), for: SupabaseConfig.Tables.cattle)
    }

    /// Push local changes to Supabase
    func pushToSupabase(_ cattle: Cattle) async throws {
        try requireAuth()

        // Try to update first, if it fails (record doesn't exist), create it
        if let id = cattle.id {
            do {
                // Try to fetch to check if exists
                _ = try await fetchById(id)
                // If fetch succeeds, update
                _ = try await update(cattle)
            } catch {
                // If fetch fails (doesn't exist), create
                _ = try await create(cattle)
            }
        } else {
            // No ID, must be new - create
            _ = try await create(cattle)
        }
    }

    /// Full bidirectional sync
    func fullSync() async throws {
        // 1. Fetch from Supabase and update local
        try await syncFromSupabase()

        // 2. Push any unsynced local changes
        // (This requires tracking dirty/unsynced records - future enhancement)
    }
}

// MARK: - Convenience Methods

extension CattleRepository {
    /// Get cattle count from Supabase
    func count() async throws -> Int {
        try requireAuth()

        let farmId = try await getFarmId()

        let response = try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .select("count", head: true)
            .eq("farm_id", value: farmId.uuidString)
            .execute()

        // Parse count from response header
        return response.count ?? 0
    }

    /// Search cattle by tag number
    func searchByTag(_ tag: String) async throws -> [CattleDTO] {
        try requireAuth()

        let farmId = try await getFarmId()

        let cattle: [CattleDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.cattle)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .ilike("tag_number", pattern: "%\(tag)%")
            .execute()
            .value

        return cattle
    }
}
