//
//  MortalityRecordRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Mortality Records with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class MortalityRecordRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all mortality records for current user from Supabase
    func fetchAll() async throws -> [MortalityRecordDTO] {
        try requireAuth()

        guard userId != nil else {
            throw RepositoryError.notAuthenticated
        }

        // Fetch all mortality records
        let records: [MortalityRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.mortalityRecords)
            .select()
            .order("death_date", ascending: false)
            .execute()
            .value

        return records
    }

    /// Fetch mortality records for specific cattle
    func fetchByCattleId(_ cattleId: UUID) async throws -> [MortalityRecordDTO] {
        try requireAuth()

        let records: [MortalityRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.mortalityRecords)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .order("death_date", ascending: false)
            .execute()
            .value

        return records
    }

    // MARK: - Create/Update/Delete

    /// Create new mortality record in Supabase
    func create(_ record: MortalityRecord) async throws -> MortalityRecordDTO {
        try requireAuth()

        let dto = MortalityRecordDTO(from: record)

        let created: MortalityRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.mortalityRecords)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing mortality record in Supabase
    func update(_ record: MortalityRecord) async throws -> MortalityRecordDTO {
        try requireAuth()

        guard let id = record.id else {
            throw RepositoryError.invalidData
        }

        let dto = MortalityRecordDTO(from: record)

        let updated: MortalityRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.mortalityRecords)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Soft delete mortality record from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.mortalityRecords)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<MortalityRecord> = MortalityRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let record = try self.context.fetch(fetchRequest).first {
                record.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all mortality records: fetch from Supabase and update Core Data with deletion support
    func syncFromSupabase() async throws {
        try await syncWithDeletions(
            entityType: MortalityRecord.self,
            tableName: SupabaseConfig.Tables.mortalityRecords,
            updateEntity: { (record: MortalityRecord, dto: Any) in
                guard let dict = dto as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let mortalityDTO = try? JSONDecoder().decode(MortalityRecordDTO.self, from: data) else {
                    throw RepositoryError.invalidData
                }

                // Update from DTO
                mortalityDTO.update(record)

                // Resolve cattle relationship
                let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cattleFetch.predicate = NSPredicate(format: "id == %@", mortalityDTO.cattleId as CVarArg)
                if let cattle = try self.context.fetch(cattleFetch).first {
                    record.cattle = cattle
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

    /// Push local mortality record to Supabase
    func pushToSupabase(_ record: MortalityRecord) async throws {
        try requireAuth()

        if let id = record.id {
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
