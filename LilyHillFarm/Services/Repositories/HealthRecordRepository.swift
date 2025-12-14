//
//  HealthRecordRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Health Records with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class HealthRecordRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all health records for current user from Supabase
    func fetchAll() async throws -> [HealthRecordDTO] {
        try requireAuth()

        guard userId != nil else {
            throw RepositoryError.notAuthenticated
        }

        // Fetch all health records
        let records: [HealthRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
            .select()
            .order("date", ascending: false)
            .execute()
            .value

        // Filter to only include records for user's cattle
        // This requires checking against locally synced cattle
        return records
    }

    /// Fetch health records for specific cattle
    func fetchByCattleId(_ cattleId: UUID) async throws -> [HealthRecordDTO] {
        try requireAuth()

        let records: [HealthRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .order("date", ascending: false)
            .execute()
            .value

        return records
    }

    // MARK: - Create/Update/Delete

    /// Create new health record in Supabase
    func create(_ record: HealthRecord) async throws -> HealthRecordDTO {
        try requireAuth()

        let dto = HealthRecordDTO(from: record)

        let created: HealthRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing health record in Supabase
    func update(_ record: HealthRecord) async throws -> HealthRecordDTO {
        try requireAuth()

        guard let id = record.id else {
            throw RepositoryError.invalidData
        }

        let dto = HealthRecordDTO(from: record)

        let updated: HealthRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Soft delete health record from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let record = try self.context.fetch(fetchRequest).first {
                record.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all health records: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        try requireAuth()

        let farmId = try await getFarmId()
        let lastSync = getLastSyncDate(for: SupabaseConfig.Tables.healthRecords) ?? Date.distantPast

        print("🔄 Syncing health_records with deletion support...")
        print("   Last sync: \(lastSync)")
        print("   Farm ID: \(farmId)")

        // Fetch CHANGED/NEW health records for this farm (modified since last sync)
        print("   📥 Fetching health records modified since \(lastSync)...")
        let activeRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .is("deleted_at", value: nil)
            .gte("updated_at", value: lastSync.ISO8601Format())
            .execute()
            .data

        let decoder = JSONDecoder()
        let activeRecords = try decoder.decode([HealthRecordDTO].self, from: activeRecordsData)
        print("   ✅ Fetched \(activeRecords.count) modified/new health records")

        // Fetch records deleted since last sync
        print("   📥 Fetching deleted records since last sync...")
        let deletedRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
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

            // Get local active health record IDs
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "HealthRecord")
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["id"]
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)

            let localRecords = try self.context.fetch(fetchRequest) as! [[String: Any]]
            let localIdSet = Set(localRecords.compactMap { $0["id"] as? UUID })
            print("   📊 Found \(localIdSet.count) local active health records")

            // 5. Create/update active records
            print("   💾 Updating \(activeRecords.count) health records...")
            for healthDTO in activeRecords {
                let entityFetch: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
                entityFetch.predicate = NSPredicate(format: "id == %@", healthDTO.id as CVarArg)

                let healthRecord: HealthRecord
                if let existing = try self.context.fetch(entityFetch).first {
                    healthRecord = existing
                } else {
                    healthRecord = HealthRecord(context: self.context)
                }

                // Update from DTO
                healthDTO.update(healthRecord)

                // Resolve cattle relationship
                if let cattleId = healthDTO.cattleId {
                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                    if let cattle = try self.context.fetch(cattleFetch).first {
                        healthRecord.cattle = cattle
                        // Set farmId from cattle
                        healthRecord.farmId = cattle.farmId
                    }
                }

                // Resolve treatment plan relationship (if present)
                if let treatmentPlanId = healthDTO.treatmentPlanId {
                    let treatmentPlanFetch: NSFetchRequest<TreatmentPlan> = TreatmentPlan.fetchRequest()
                    treatmentPlanFetch.predicate = NSPredicate(format: "id == %@", treatmentPlanId as CVarArg)
                    if let treatmentPlan = try self.context.fetch(treatmentPlanFetch).first {
                        healthRecord.treatmentPlan = treatmentPlan
                    }
                }
            }

            // 6. Soft delete records that were deleted on server
            print("   🗑️ Marking \(deletedRecords.count) records as deleted...")
            for deletedRecord in deletedRecords {
                let fetchRequest: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", deletedRecord.id as CVarArg)

                if let record = try self.context.fetch(fetchRequest).first {
                    record.deletedAt = Date()
                    print("   🗑️ Marked HealthRecord \(deletedRecord.id) as deleted")
                }
            }

            // 7. Handle orphaned records ONLY during full sync (when lastSync is distantPast)
            // During incremental sync, we can't determine orphans because we only fetched changed records
            if lastSync == Date.distantPast {
                let serverIdSet = Set(activeRecords.map { $0.id })
                let deletedIdSet = Set(deletedRecords.map { $0.id })
                let orphanedIds = localIdSet.subtracting(serverIdSet).subtracting(deletedIdSet)

                if !orphanedIds.isEmpty {
                    print("   ⚠️ Found \(orphanedIds.count) orphaned health records to hard delete (full sync only)")
                    for orphanedId in orphanedIds {
                        let fetchRequest: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "id == %@", orphanedId as CVarArg)

                        if let record = try self.context.fetch(fetchRequest).first {
                            self.context.delete(record)
                            print("   🗑️ Hard deleted HealthRecord \(orphanedId)")
                        }
                    }
                }
            } else {
                print("   ℹ️ Skipping orphan detection (incremental sync)")
            }

            // 8. Save context
            print("   💾 Saving Core Data context...")
            try self.saveContext()
            print("   ✅ Sync completed for health_records")
        }

        // 9. Update last sync timestamp
        setLastSyncDate(Date(), for: SupabaseConfig.Tables.healthRecords)
    }

    /// Push local health record to Supabase
    func pushToSupabase(_ record: HealthRecord) async throws {
        try requireAuth()

        if record.id != nil {
            do {
                // Try to update, if it fails (doesn't exist), create
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
