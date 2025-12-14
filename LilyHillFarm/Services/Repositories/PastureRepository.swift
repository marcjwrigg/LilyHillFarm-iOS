//
//  PastureRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Pastures with Supabase
//

import Foundation
internal import CoreData
import Supabase

class PastureRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all pastures from Supabase for current farm
    func fetchAll() async throws -> [PastureDTO] {
        try requireAuth()
        let farmId = try await getFarmId()

        let pastures: [PastureDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.pastures)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .is("deleted_at", value: nil)
            .order("name")
            .execute()
            .value

        return pastures
    }

    // MARK: - Sync

    /// Sync pastures: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching pastures from Supabase...")
        let pastureDTOs = try await fetchAll()
        print("✅ Fetched \(pastureDTOs.count) pastures from Supabase")

        // Get farmId BEFORE context.perform
        let farmId = try await getFarmId()

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(pastureDTOs.count) pastures to Core Data...")

            let supabaseIds = Set(pastureDTOs.map { $0.id })

            let fetchRequest: NSFetchRequest<Pasture> = Pasture.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)
            let allLocalPastures = try self.context.fetch(fetchRequest)

            for localPasture in allLocalPastures {
                guard let localId = localPasture.id else {
                    self.context.delete(localPasture)
                    continue
                }
                if !supabaseIds.contains(localId) {
                    self.context.delete(localPasture)
                    print("   🗑️ Deleted pasture \(localPasture.name ?? "unknown")")
                }
            }

            for dto in pastureDTOs {
                let fetchRequest: NSFetchRequest<Pasture> = Pasture.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let pasture: Pasture
                if let existing = try self.context.fetch(fetchRequest).first {
                    pasture = existing
                } else {
                    pasture = Pasture(context: self.context)
                }

                dto.update(pasture)
            }

            if self.context.hasChanges {
                print("💾 Saving pastures to Core Data...")
                try self.saveContext()
                print("✅ Pastures sync completed!")
            } else {
                print("✅ Pastures sync completed (no changes needed)")
            }
        }
    }
}
