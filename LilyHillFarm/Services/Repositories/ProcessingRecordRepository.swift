//
//  ProcessingRecordRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Processing Records with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class ProcessingRecordRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all processing records for current user from Supabase
    func fetchAll() async throws -> [ProcessingRecordDTO] {
        try requireAuth()

        guard userId != nil else {
            throw RepositoryError.notAuthenticated
        }

        // Fetch all processing records
        let records: [ProcessingRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.processingRecords)
            .select()
            .order("processing_date", ascending: false)
            .execute()
            .value

        return records
    }

    /// Fetch processing records for specific cattle
    func fetchByCattleId(_ cattleId: UUID) async throws -> [ProcessingRecordDTO] {
        try requireAuth()

        let records: [ProcessingRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.processingRecords)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .order("processing_date", ascending: false)
            .execute()
            .value

        return records
    }

    // MARK: - Create/Update/Delete

    /// Create new processing record in Supabase
    func create(_ record: ProcessingRecord) async throws -> ProcessingRecordDTO {
        try requireAuth()

        let dto = ProcessingRecordDTO(from: record)

        let created: ProcessingRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.processingRecords)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing processing record in Supabase
    func update(_ record: ProcessingRecord) async throws -> ProcessingRecordDTO {
        try requireAuth()

        guard let id = record.id else {
            throw RepositoryError.invalidData
        }

        let dto = ProcessingRecordDTO(from: record)

        let updated: ProcessingRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.processingRecords)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Soft delete processing record from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.processingRecords)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<ProcessingRecord> = ProcessingRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let record = try self.context.fetch(fetchRequest).first {
                record.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all processing records: fetch from Supabase and update Core Data with deletion support
    func syncFromSupabase() async throws {
        try await syncWithDeletions(
            entityType: ProcessingRecord.self,
            tableName: SupabaseConfig.Tables.processingRecords,
            updateEntity: { (record: ProcessingRecord, dto: Any) in
                guard let dict = dto as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let processingDTO = try? JSONDecoder().decode(ProcessingRecordDTO.self, from: data) else {
                    throw RepositoryError.invalidData
                }

                // Update from DTO
                processingDTO.update(record)

                // Resolve cattle relationship
                let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cattleFetch.predicate = NSPredicate(format: "id == %@", processingDTO.cattleId as CVarArg)
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

    /// Push local processing record to Supabase
    func pushToSupabase(_ record: ProcessingRecord) async throws {
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
