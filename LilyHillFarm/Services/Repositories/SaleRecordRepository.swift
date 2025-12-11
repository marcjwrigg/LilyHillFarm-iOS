//
//  SaleRecordRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Sale Records with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class SaleRecordRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all sale records for current user from Supabase
    func fetchAll() async throws -> [SaleRecordDTO] {
        try requireAuth()

        guard userId != nil else {
            throw RepositoryError.notAuthenticated
        }

        // Fetch all sale records
        let records: [SaleRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.saleRecords)
            .select()
            .order("sale_date", ascending: false)
            .execute()
            .value

        return records
    }

    /// Fetch sale records for specific cattle
    func fetchByCattleId(_ cattleId: UUID) async throws -> [SaleRecordDTO] {
        try requireAuth()

        let records: [SaleRecordDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.saleRecords)
            .select()
            .eq("cattle_id", value: cattleId.uuidString)
            .order("sale_date", ascending: false)
            .execute()
            .value

        return records
    }

    // MARK: - Create/Update/Delete

    /// Create new sale record in Supabase
    func create(_ record: SaleRecord) async throws -> SaleRecordDTO {
        try requireAuth()

        let dto = SaleRecordDTO(from: record)

        let created: SaleRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.saleRecords)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing sale record in Supabase
    func update(_ record: SaleRecord) async throws -> SaleRecordDTO {
        try requireAuth()

        guard let id = record.id else {
            throw RepositoryError.invalidData
        }

        let dto = SaleRecordDTO(from: record)

        let updated: SaleRecordDTO = try await supabase.client
            .from(SupabaseConfig.Tables.saleRecords)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Soft delete sale record from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        // Soft delete on server
        let update = ["deleted_at": Date().ISO8601Format()]
        try await supabase.client
            .from(SupabaseConfig.Tables.saleRecords)
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()

        // Mark deleted locally
        try await context.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest: NSFetchRequest<SaleRecord> = SaleRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let record = try self.context.fetch(fetchRequest).first {
                record.deletedAt = Date()
                try self.context.save()
            }
        }
    }

    // MARK: - Sync

    /// Sync all sale records: fetch from Supabase and update Core Data with deletion support
    func syncFromSupabase() async throws {
        try await syncWithDeletions(
            entityType: SaleRecord.self,
            tableName: SupabaseConfig.Tables.saleRecords,
            updateEntity: { (record: SaleRecord, dto: Any) in
                guard let dict = dto as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let saleDTO = try? JSONDecoder().decode(SaleRecordDTO.self, from: data) else {
                    throw RepositoryError.invalidData
                }

                // Update from DTO
                saleDTO.update(record)

                // Resolve cattle relationship
                let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cattleFetch.predicate = NSPredicate(format: "id == %@", saleDTO.cattleId as CVarArg)
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
            hasFarmId: false
        )
    }

    /// Push local sale record to Supabase
    func pushToSupabase(_ record: SaleRecord) async throws {
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
