//
//  ProductionPathRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Production Paths with Supabase
//

import Foundation
internal import CoreData
import Supabase

class ProductionPathRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all production paths from Supabase for current farm
    func fetchAll() async throws -> [ProductionPathDTO] {
        try requireAuth()
        let farmId = try await getFarmId()

        let paths: [ProductionPathDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.productionPaths)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("name")
            .execute()
            .value

        return paths
    }

    /// Fetch single production path by ID
    func fetchById(_ id: UUID) async throws -> ProductionPathDTO? {
        let path: ProductionPathDTO = try await supabase.client
            .from(SupabaseConfig.Tables.productionPaths)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return path
    }

    // MARK: - Sync

    /// Sync production paths: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching production paths from Supabase...")
        let pathDTOs = try await fetchAll()
        print("✅ Fetched \(pathDTOs.count) production paths from Supabase")

        // Get farmId BEFORE context.perform
        let farmId = try await getFarmId()

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(pathDTOs.count) production paths to Core Data...")

            // Get IDs from Supabase
            let supabaseIds = Set(pathDTOs.map { $0.id })

            // Fetch all local paths for this farm
            let fetchRequest: NSFetchRequest<ProductionPath> = ProductionPath.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@", farmId as CVarArg)
            let allLocalPaths = try self.context.fetch(fetchRequest)

            // Delete paths that exist locally but not in Supabase
            for localPath in allLocalPaths {
                guard let localId = localPath.id else {
                    self.context.delete(localPath)
                    continue
                }

                if !supabaseIds.contains(localId) {
                    self.context.delete(localPath)
                    print("   🗑️ Deleted production path \(localPath.name ?? "unknown") (ID: \(localId))")
                }
            }

            // Now sync paths from Supabase
            for dto in pathDTOs {
                let fetchRequest: NSFetchRequest<ProductionPath> = ProductionPath.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let results = try self.context.fetch(fetchRequest)

                let path: ProductionPath
                if let existing = results.first {
                    path = existing
                } else {
                    path = ProductionPath(context: self.context)
                }

                // Update from DTO
                dto.update(path)
            }

            // Only save if there are actual changes
            if self.context.hasChanges {
                print("💾 Saving production paths to Core Data...")
                try self.saveContext()
                print("✅ Production paths sync completed!")
            } else {
                print("✅ Production paths sync completed (no changes needed)")
            }
        }
    }
}
