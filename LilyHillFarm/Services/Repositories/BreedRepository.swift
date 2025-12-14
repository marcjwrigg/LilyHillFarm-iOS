//
//  BreedRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Breeds (reference data) with Supabase
//

import Foundation
internal import CoreData
import Supabase

class BreedRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all breeds from Supabase (reference data - no user filtering)
    func fetchAll() async throws -> [BreedDTO] {
        // Fetch ALL breeds (including inactive ones) since cattle may reference them
        let breeds: [BreedDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.breeds)
            .select()
            .order("name")
            .execute()
            .value

        return breeds
    }

    /// Fetch single breed by ID
    func fetchById(_ id: UUID) async throws -> BreedDTO? {
        let breed: BreedDTO = try await supabase.client
            .from(SupabaseConfig.Tables.breeds)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return breed
    }

    // MARK: - Sync

    /// Sync all breeds: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching breeds from Supabase...")
        let breedDTOs = try await fetchAll()
        print("✅ Fetched \(breedDTOs.count) breeds from Supabase")

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(breedDTOs.count) breeds to Core Data...")

            // Get IDs from Supabase
            let supabaseIds = Set(breedDTOs.map { $0.id })

            // Fetch all local breeds
            let fetchRequest: NSFetchRequest<Breed> = Breed.fetchRequest()
            let allLocalBreeds = try self.context.fetch(fetchRequest)

            // Delete breeds that exist locally but not in Supabase, or are duplicates
            var seenIds = Set<UUID>()
            for localBreed in allLocalBreeds {
                guard let localId = localBreed.id else {
                    // Delete breeds without IDs
                    self.context.delete(localBreed)
                    continue
                }

                if !supabaseIds.contains(localId) || seenIds.contains(localId) {
                    // Delete if not in Supabase or is a duplicate
                    self.context.delete(localBreed)
                    print("   🗑️ Deleted breed \(localBreed.name ?? "unknown") (ID: \(localId))")
                } else {
                    seenIds.insert(localId)
                }
            }

            // Now sync breeds from Supabase
            for dto in breedDTOs {
                // Try to find existing breed (should only find one now after deduplication)
                let fetchRequest: NSFetchRequest<Breed> = Breed.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let results = try self.context.fetch(fetchRequest)

                let breed: Breed
                if let existing = results.first {
                    // Update existing
                    breed = existing
                } else {
                    // Create new
                    breed = Breed(context: self.context)
                }

                // Update from DTO
                dto.update(breed)
            }

            // Only save if there are actual changes
            if self.context.hasChanges {
                print("💾 Saving breeds to Core Data...")
                try self.saveContext()
                print("✅ Breeds sync completed!")
            } else {
                print("✅ Breeds sync completed (no changes needed)")
            }
        }
    }
}
