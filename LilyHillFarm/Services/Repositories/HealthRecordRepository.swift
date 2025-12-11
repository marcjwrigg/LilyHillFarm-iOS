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

        // 1. Get all cattle IDs for this farm from Core Data
        var cattleIds: [UUID] = []
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)
            fetchRequest.propertiesToFetch = ["id"]
            let cattle = try self.context.fetch(fetchRequest)
            cattleIds = cattle.compactMap { $0.id }
        }

        guard !cattleIds.isEmpty else {
            print("   ⚠️ No cattle found for farm, skipping health records sync")
            return
        }

        print("   📊 Found \(cattleIds.count) cattle for this farm")

        // 2. Fetch active health records for these cattle
        print("   📥 Fetching active health records...")
        let cattleIdStrings = cattleIds.map { $0.uuidString }
        let activeRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
            .select()
            .in("cattle_id", values: cattleIdStrings)
            .is("deleted_at", value: nil)
            .execute()
            .data

        let decoder = JSONDecoder()
        let activeRecords = try decoder.decode([HealthRecordDTO].self, from: activeRecordsData)
        print("   ✅ Fetched \(activeRecords.count) active health records")

        // 3. Fetch records deleted since last sync
        print("   📥 Fetching deleted records since last sync...")
        let deletedRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecords)
            .select("id, deleted_at")
            .in("cattle_id", values: cattleIdStrings)
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
                let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cattleFetch.predicate = NSPredicate(format: "id == %@", healthDTO.cattleId as CVarArg)
                if let cattle = try self.context.fetch(cattleFetch).first {
                    healthRecord.cattle = cattle
                    // Set farmId from cattle
                    healthRecord.farmId = cattle.farmId
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

            // 7. Handle orphaned records
            let serverIdSet = Set(activeRecords.map { $0.id })
            let deletedIdSet = Set(deletedRecords.map { $0.id })
            let orphanedIds = localIdSet.subtracting(serverIdSet).subtracting(deletedIdSet)

            if !orphanedIds.isEmpty {
                print("   ⚠️ Found \(orphanedIds.count) orphaned health records")
                print("   🗑️ Hard deleting orphaned records...")
                for orphanedId in orphanedIds {
                    let fetchRequest: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", orphanedId as CVarArg)

                    if let record = try self.context.fetch(fetchRequest).first {
                        self.context.delete(record)
                        print("   🗑️ Hard deleted HealthRecord \(orphanedId)")
                    }
                }
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
