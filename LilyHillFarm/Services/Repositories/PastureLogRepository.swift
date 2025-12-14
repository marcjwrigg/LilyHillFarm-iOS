//
//  PastureLogRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Pasture Logs with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class PastureLogRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all pasture logs from Supabase for current farm
    func fetchAll() async throws -> [PastureLogDTO] {
        try requireAuth()
        let farmId = try await getFarmId()

        let logs: [PastureLogDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.pastureLogs)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("log_date", ascending: false)
            .execute()
            .value

        return logs
    }

    /// Fetch pasture logs for specific pasture
    func fetchByPastureId(_ pastureId: UUID) async throws -> [PastureLogDTO] {
        try requireAuth()

        let logs: [PastureLogDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.pastureLogs)
            .select()
            .eq("pasture_id", value: pastureId.uuidString)
            .order("log_date", ascending: false)
            .execute()
            .value

        return logs
    }

    // MARK: - Create/Update/Delete

    /// Create new pasture log in Supabase
    func create(_ log: PastureLog) async throws -> PastureLogDTO {
        try requireAuth()

        let farmId = try await getFarmId()

        let dto = PastureLogDTO(from: log, farmId: farmId)

        print("📤 PastureLogRepository.create() - Inserting log:")
        print("  - ID: \(dto.id)")
        print("  - Title: \(dto.title)")
        print("  - Pasture ID: \(dto.pastureId)")

        do {
            // Insert without selecting back to avoid RLS issues
            try await supabase.client
                .from(SupabaseConfig.Tables.pastureLogs)
                .insert(dto)
                .execute()

            print("✅ PastureLogRepository.create() - Insert successful")
            return dto
        } catch {
            print("❌ PastureLogRepository.create() - Insert failed: \(error)")
            throw error
        }
    }

    /// Update existing pasture log in Supabase
    func update(_ log: PastureLog) async throws -> PastureLogDTO {
        try requireAuth()

        guard let id = log.id else {
            throw RepositoryError.invalidData
        }

        let farmId = try await getFarmId()

        let dto = PastureLogDTO(from: log, farmId: farmId)

        // Update without selecting back to avoid RLS issues
        try await supabase.client
            .from(SupabaseConfig.Tables.pastureLogs)
            .update(dto)
            .eq("id", value: id.uuidString)
            .execute()

        return dto
    }

    /// Delete pasture log from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        try await supabase.client
            .from(SupabaseConfig.Tables.pastureLogs)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Sync

    /// Sync all pasture logs: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching pasture logs from Supabase...")
        let logDTOs = try await fetchAll()
        print("✅ Fetched \(logDTOs.count) pasture logs from Supabase")

        // Get farmId BEFORE context.perform
        let farmId = try await getFarmId()

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(logDTOs.count) pasture logs to Core Data...")

            let supabaseIds = Set(logDTOs.map { $0.id })

            let fetchRequest: NSFetchRequest<PastureLog> = PastureLog.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@", farmId as CVarArg)
            let allLocalLogs = try self.context.fetch(fetchRequest)

            for localLog in allLocalLogs {
                guard let localId = localLog.id else {
                    self.context.delete(localLog)
                    continue
                }
                if !supabaseIds.contains(localId) {
                    self.context.delete(localLog)
                    print("   🗑️ Deleted pasture log \(localLog.title ?? "unknown")")
                }
            }

            for dto in logDTOs {
                let fetchRequest: NSFetchRequest<PastureLog> = PastureLog.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let log: PastureLog
                if let existing = try self.context.fetch(fetchRequest).first {
                    log = existing
                } else {
                    log = PastureLog(context: self.context)
                }

                dto.update(log)

                // Link to pasture
                let pastureFetch: NSFetchRequest<Pasture> = Pasture.fetchRequest()
                pastureFetch.predicate = NSPredicate(format: "id == %@", dto.pastureId as CVarArg)
                if let pasture = try self.context.fetch(pastureFetch).first {
                    log.pasture = pasture
                }
            }

            if self.context.hasChanges {
                print("💾 Saving pasture logs to Core Data...")
                try self.saveContext()
                print("✅ Pasture logs sync completed!")
            } else {
                print("✅ Pasture logs sync completed (no changes needed)")
            }
        }
    }

    /// Push local pasture log to Supabase
    func pushToSupabase(_ log: PastureLog) async throws {
        try requireAuth()

        if log.id != nil {
            do {
                // Try to update, if it fails (doesn't exist), create
                _ = try await update(log)
            } catch {
                // If update fails (doesn't exist), create
                _ = try await create(log)
            }
        } else {
            // No ID, must be new - create
            _ = try await create(log)
        }
    }
}
