//
//  HealthRecordTypeRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Health Record Types with Supabase
//

import Foundation
internal import CoreData
import Supabase

class HealthRecordTypeRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all health record types from Supabase (system-wide data)
    func fetchAll() async throws -> [HealthRecordTypeDTO] {
        let types: [HealthRecordTypeDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecordTypes)
            .select()
            .eq("is_active", value: true)
            .order("name")
            .execute()
            .value

        return types
    }

    /// Fetch single health record type by ID
    func fetchById(_ id: UUID) async throws -> HealthRecordTypeDTO? {
        let type: HealthRecordTypeDTO = try await supabase.client
            .from(SupabaseConfig.Tables.healthRecordTypes)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return type
    }

    // MARK: - Sync

    /// Sync health record types: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching health record types from Supabase...")
        let typeDTOs = try await fetchAll()
        print("✅ Fetched \(typeDTOs.count) health record types from Supabase")

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(typeDTOs.count) health record types to Core Data...")

            // Get IDs from Supabase
            let supabaseIds = Set(typeDTOs.map { $0.id })

            // Fetch all local types
            let fetchRequest: NSFetchRequest<HealthRecordType> = HealthRecordType.fetchRequest()
            let allLocalTypes = try self.context.fetch(fetchRequest)

            // Delete types that exist locally but not in Supabase
            for localType in allLocalTypes {
                guard let localId = localType.id else {
                    self.context.delete(localType)
                    continue
                }

                if !supabaseIds.contains(localId) {
                    self.context.delete(localType)
                    print("   🗑️ Deleted health record type \(localType.name ?? "unknown") (ID: \(localId))")
                }
            }

            // Now sync types from Supabase
            for dto in typeDTOs {
                let fetchRequest: NSFetchRequest<HealthRecordType> = HealthRecordType.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let results = try self.context.fetch(fetchRequest)

                let type: HealthRecordType
                if let existing = results.first {
                    type = existing
                } else {
                    type = HealthRecordType(context: self.context)
                }

                // Update from DTO
                dto.update(type)
            }

            // Only save if there are actual changes
            if self.context.hasChanges {
                print("💾 Saving health record types to Core Data...")
                try self.saveContext()
                print("✅ Health record types sync completed!")
            } else {
                print("✅ Health record types sync completed (no changes needed)")
            }
        }
    }
}
