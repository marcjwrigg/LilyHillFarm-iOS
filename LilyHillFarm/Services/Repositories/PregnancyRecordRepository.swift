//
//  PregnancyRecordRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Pregnancy Records with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class PregnancyRecordRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all pregnancy records for current user from Supabase
    func fetchAll() async throws -> [PregnancyRecordDTO] {
        try requireAuth()

        guard userId != nil else {
            throw RepositoryError.notAuthenticated
        }

        // Fetch all pregnancy records
        let records: [PregnancyRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.pregnancyRecords)
            .select()
            .order("breeding_start_date", ascending: false)
            .execute()
            .value

        // Filter to only include records for user's cattle
        // This requires checking against locally synced cattle
        return records
    }

    /// Fetch pregnancy records for specific cow/dam
    func fetchByCowId(_ cowId: UUID) async throws -> [PregnancyRecordDTO] {
        try requireAuth()

        let records: [PregnancyRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.pregnancyRecords)
            .select()
            .eq("dam_id", value: cowId.uuidString)
            .order("breeding_start_date", ascending: false)
            .execute()
            .value

        return records
    }

    // MARK: - Create/Update/Delete

    /// Create new pregnancy record in Supabase
    func create(_ record: PregnancyRecord) async throws -> PregnancyRecordDTO {
        try requireAuth()

        let dto = PregnancyRecordDTO(from: record)

        let created: PregnancyRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.pregnancyRecords)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing pregnancy record in Supabase
    func update(_ record: PregnancyRecord) async throws -> PregnancyRecordDTO {
        try requireAuth()

        guard let id = record.id else {
            throw RepositoryError.invalidData
        }

        let dto = PregnancyRecordDTO(from: record)

        let updated: PregnancyRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.pregnancyRecords)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Soft delete pregnancy record from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.pregnancyRecords)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let record = try self.context.fetch(fetchRequest).first {
                record.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all pregnancy records: fetch from Supabase and update Core Data with deletion support
    /// Since pregnancy_records don't have farm_id, we need to fetch by user's cattle IDs
    func syncFromSupabase() async throws {
        try requireAuth()

        let farmId = try await getFarmId()
        let lastSync = getLastSyncDate(for: SupabaseConfig.Tables.pregnancyRecords) ?? Date.distantPast

        print("🔄 Syncing pregnancy_records with deletion support...")
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
            print("   ⚠️ No cattle found for farm, skipping pregnancy sync")
            return
        }

        print("   📊 Found \(cattleIds.count) cattle for this farm")

        // 2. Fetch active pregnancy records for these cattle
        print("   📥 Fetching active pregnancy records...")
        let cattleIdStrings = cattleIds.map { $0.uuidString }
        let activeRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.pregnancyRecords)
            .select()
            .in("cow_id", values: cattleIdStrings)
            .is("deleted_at", value: nil)
            .execute()
            .data

        let decoder = JSONDecoder()
        let activeRecords = try decoder.decode([PregnancyRecordDTO].self, from: activeRecordsData)
        print("   ✅ Fetched \(activeRecords.count) active pregnancy records")

        // 3. Fetch records deleted since last sync
        print("   📥 Fetching deleted records since last sync...")
        let deletedRecordsData = try await supabase.client
            .from(SupabaseConfig.Tables.pregnancyRecords)
            .select("id, deleted_at")
            .in("cow_id", values: cattleIdStrings)
            .gt("deleted_at", value: lastSync.ISO8601Format())
            .execute()
            .data

        let deletedRecords = try decoder.decode([DeletedRecord].self, from: deletedRecordsData)
        print("   ✅ Found \(deletedRecords.count) deleted records")

        // 4. Update Core Data
        try await context.perform { [weak self] in
            guard let self = self else { return }

            // Get local active pregnancy record IDs
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PregnancyRecord")
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["id"]
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)

            let localRecords = try self.context.fetch(fetchRequest) as! [[String: Any]]
            let localIdSet = Set(localRecords.compactMap { $0["id"] as? UUID })
            print("   📊 Found \(localIdSet.count) local active pregnancy records")

            // 5. Create/update active records
            print("   💾 Updating \(activeRecords.count) pregnancy records...")
            for pregnancyDTO in activeRecords {
                let entityFetch: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
                entityFetch.predicate = NSPredicate(format: "id == %@", pregnancyDTO.id as CVarArg)

                let pregnancyRecord: PregnancyRecord
                if let existing = try self.context.fetch(entityFetch).first {
                    pregnancyRecord = existing
                } else {
                    pregnancyRecord = PregnancyRecord(context: self.context)
                }

                // Update from DTO
                pregnancyDTO.update(pregnancyRecord)

                // Resolve cow (dam) relationship
                let cowFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cowFetch.predicate = NSPredicate(format: "id == %@", pregnancyDTO.damId as CVarArg)
                if let cow = try self.context.fetch(cowFetch).first {
                    pregnancyRecord.cow = cow
                    // Set farmId from cow
                    pregnancyRecord.farmId = cow.farmId
                }

                // Resolve bull (sire) relationship (optional)
                if let sireId = pregnancyDTO.sireId {
                    let bullFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    bullFetch.predicate = NSPredicate(format: "id == %@", sireId as CVarArg)
                    if let bull = try self.context.fetch(bullFetch).first {
                        pregnancyRecord.bull = bull
                    }
                }
            }

            // 6. Soft delete records that were deleted on server
            print("   🗑️ Marking \(deletedRecords.count) records as deleted...")
            for deletedRecord in deletedRecords {
                let fetchRequest: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", deletedRecord.id as CVarArg)

                if let record = try self.context.fetch(fetchRequest).first {
                    record.deletedAt = Date()
                    print("   🗑️ Marked PregnancyRecord \(deletedRecord.id) as deleted")
                }
            }

            // 7. Handle orphaned records (exist locally but not in server's active set)
            let serverIdSet = Set(activeRecords.map { $0.id })
            let deletedIdSet = Set(deletedRecords.map { $0.id })
            let orphanedIds = localIdSet.subtracting(serverIdSet).subtracting(deletedIdSet)

            if !orphanedIds.isEmpty {
                print("   ⚠️ Found \(orphanedIds.count) orphaned pregnancy records")
                print("   🗑️ Hard deleting orphaned records (not found on server)...")
                for orphanedId in orphanedIds {
                    let fetchRequest: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", orphanedId as CVarArg)

                    if let record = try self.context.fetch(fetchRequest).first {
                        self.context.delete(record)
                        print("   🗑️ Hard deleted PregnancyRecord \(orphanedId)")
                    }
                }
            }

            // 8. Save context
            print("   💾 Saving Core Data context...")
            try self.saveContext()
            print("   ✅ Sync completed for pregnancy_records")
        }

        // 9. Update last sync timestamp
        setLastSyncDate(Date(), for: SupabaseConfig.Tables.pregnancyRecords)
    }

    /// Push local pregnancy record to Supabase
    func pushToSupabase(_ record: PregnancyRecord) async throws {
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
