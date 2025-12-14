//
//  CalvingRecordRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Calving Records with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class CalvingRecordRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all calving records for current user from Supabase
    func fetchAll() async throws -> [CalvingRecordDTO] {
        try requireAuth()

        guard userId != nil else {
            throw RepositoryError.notAuthenticated
        }

        // Fetch all calving records
        let records: [CalvingRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.calvingRecords)
            .select()
            .order("calving_date", ascending: false)
            .execute()
            .value

        // Filter to only include records for user's cattle
        // This requires checking against locally synced cattle
        return records
    }

    /// Fetch calving records for specific cow
    func fetchByDamId(_ damId: UUID) async throws -> [CalvingRecordDTO] {
        try requireAuth()

        let records: [CalvingRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.calvingRecords)
            .select()
            .eq("dam_id", value: damId.uuidString)
            .order("calving_date", ascending: false)
            .execute()
            .value

        return records
    }

    // MARK: - Create/Update/Delete

    /// Create new calving record in Supabase
    func create(_ record: CalvingRecord) async throws -> CalvingRecordDTO {
        try requireAuth()

        let dto = CalvingRecordDTO(from: record)

        let created: CalvingRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.calvingRecords)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing calving record in Supabase
    func update(_ record: CalvingRecord) async throws -> CalvingRecordDTO {
        try requireAuth()

        guard let id = record.id else {
            throw RepositoryError.invalidData
        }

        let dto = CalvingRecordDTO(from: record)

        let updated: CalvingRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.calvingRecords)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Soft delete calving record from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.calvingRecords)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let record = try self.context.fetch(fetchRequest).first {
                record.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all calving records: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        try requireAuth()

        let farmId = try await getFarmId()
        let lastSync = getLastSyncDate(for: SupabaseConfig.Tables.calvingRecords) ?? Date.distantPast

        print("🔄 Syncing calving_records with deletion support...")
        print("   Last sync: \(lastSync)")
        print("   Farm ID: \(farmId)")

        // Fetch CHANGED/NEW calving records for this farm (modified since last sync)
        print("   📥 Fetching calving records modified since \(lastSync)...")
        let activeRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.calvingRecords)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .is("deleted_at", value: nil)
            .gte("updated_at", value: lastSync.ISO8601Format())
            .execute()
            .data

        let decoder = JSONDecoder()
        let activeRecords = try decoder.decode([CalvingRecordDTO].self, from: activeRecordsData)
        print("   ✅ Fetched \(activeRecords.count) modified/new calving records")

        // Fetch records deleted since last sync
        print("   📥 Fetching deleted records since last sync...")
        let deletedRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.calvingRecords)
            .select("id, deleted_at")
            .eq("farm_id", value: farmId.uuidString)
            .gt("deleted_at", value: lastSync.ISO8601Format())
            .execute()
            .data

        let deletedRecords = try decoder.decode([DeletedRecord].self, from: deletedRecordsData)
        print("   ✅ Found \(deletedRecords.count) deleted records")

        // 4. Update Core Data
        try await context.perform { [weak self] in
            guard let self = self else { return }

            // Get local active calving record IDs
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CalvingRecord")
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["id"]
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)

            let localRecords = try self.context.fetch(fetchRequest) as! [[String: Any]]
            let localIdSet = Set(localRecords.compactMap { $0["id"] as? UUID })
            print("   📊 Found \(localIdSet.count) local active calving records")

            // 5. Create/update active records
            print("   💾 Updating \(activeRecords.count) calving records...")
            for calvingDTO in activeRecords {
                let entityFetch: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
                entityFetch.predicate = NSPredicate(format: "id == %@", calvingDTO.id as CVarArg)

                let calvingRecord: CalvingRecord
                if let existing = try self.context.fetch(entityFetch).first {
                    calvingRecord = existing
                } else {
                    calvingRecord = CalvingRecord(context: self.context)
                }

                // Update from DTO
                calvingDTO.update(calvingRecord)

                // Resolve dam relationship
                let damFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                damFetch.predicate = NSPredicate(format: "id == %@", calvingDTO.damId as CVarArg)
                if let dam = try self.context.fetch(damFetch).first {
                    calvingRecord.dam = dam
                    // Set farmId from dam
                    calvingRecord.farmId = dam.farmId
                }

                // Resolve sire relationship (optional)
                if let sireId = calvingDTO.sireId {
                    let sireFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    sireFetch.predicate = NSPredicate(format: "id == %@", sireId as CVarArg)
                    if let sire = try self.context.fetch(sireFetch).first {
                        calvingRecord.sire = sire
                    }
                }

                // Resolve calf relationship (optional)
                if let calfId = calvingDTO.calfId {
                    let calfFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    calfFetch.predicate = NSPredicate(format: "id == %@", calfId as CVarArg)
                    if let calf = try self.context.fetch(calfFetch).first {
                        calvingRecord.calf = calf
                    }
                }
            }

            // 6. Soft delete records that were deleted on server
            print("   🗑️ Marking \(deletedRecords.count) records as deleted...")
            for deletedRecord in deletedRecords {
                let fetchRequest: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", deletedRecord.id as CVarArg)

                if let record = try self.context.fetch(fetchRequest).first {
                    record.deletedAt = Date()
                    print("   🗑️ Marked CalvingRecord \(deletedRecord.id) as deleted")
                }
            }

            // 7. Handle orphaned records ONLY during full sync (when lastSync is distantPast)
            // During incremental sync, we can't determine orphans because we only fetched changed records
            if lastSync == Date.distantPast {
                let serverIdSet = Set(activeRecords.map { $0.id })
                let deletedIdSet = Set(deletedRecords.map { $0.id })
                let orphanedIds = localIdSet.subtracting(serverIdSet).subtracting(deletedIdSet)

                if !orphanedIds.isEmpty {
                    print("   ⚠️ Found \(orphanedIds.count) orphaned calving records to hard delete (full sync only)")
                    for orphanedId in orphanedIds {
                        let fetchRequest: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id == %@", orphanedId as CVarArg)

                        if let record = try self.context.fetch(fetchRequest).first {
                            self.context.delete(record)
                            print("   🗑️ Hard deleted CalvingRecord \(orphanedId)")
                        }
                    }
                }
            } else {
                print("   ℹ️ Skipping orphan detection (incremental sync)")
            }

            // 8. Save context
            print("   💾 Saving Core Data context...")
            try self.saveContext()
            print("   ✅ Sync completed for calving_records")
        }

        // 9. Update last sync timestamp
        setLastSyncDate(Date(), for: SupabaseConfig.Tables.calvingRecords)
    }

    /// Push local calving record to Supabase
    func pushToSupabase(_ record: CalvingRecord) async throws {
        try requireAuth()

        if record.id != nil {
            do {
                // Try to check if exists in Supabase by attempting update
                _ = try await update(record)
            } catch {
                // If update fails (doesn't exist), create
                _ = try await create(record)
            }
        } else {
            // No ID, must be new - create
            _ = try await create(record)
        }
    }
}
