//
//  VeterinarianRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Veterinarians with Supabase
//

import Foundation
internal import CoreData
import Supabase

class VeterinarianRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all veterinarians from Supabase for current farm
    func fetchAll() async throws -> [VeterinarianDTO] {
        try requireAuth()
        let farmId = try await getFarmId()

        let veterinarians: [VeterinarianDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.veterinarians)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("name")
            .execute()
            .value

        return veterinarians
    }

    // MARK: - Sync

    /// Sync veterinarians: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching veterinarians from Supabase...")
        let vetDTOs = try await fetchAll()
        print("✅ Fetched \(vetDTOs.count) veterinarians from Supabase")

        // Get farmId BEFORE context.perform
        let farmId = try await getFarmId()

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(vetDTOs.count) veterinarians to Core Data...")

            let supabaseIds = Set(vetDTOs.map { $0.id })

            let fetchRequest: NSFetchRequest<Veterinarian> = Veterinarian.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@", farmId as CVarArg)
            let allLocalVets = try self.context.fetch(fetchRequest)

            for localVet in allLocalVets {
                guard let localId = localVet.id else {
                    self.context.delete(localVet)
                    continue
                }
                if !supabaseIds.contains(localId) {
                    self.context.delete(localVet)
                    print("   🗑️ Deleted veterinarian \(localVet.name ?? "unknown")")
                }
            }

            for dto in vetDTOs {
                let fetchRequest: NSFetchRequest<Veterinarian> = Veterinarian.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let vet: Veterinarian
                if let existing = try self.context.fetch(fetchRequest).first {
                    vet = existing
                } else {
                    vet = Veterinarian(context: self.context)
                }

                dto.update(vet)
            }

            if self.context.hasChanges {
                print("💾 Saving veterinarians to Core Data...")
                try self.saveContext()
                print("✅ Veterinarians sync completed!")
            } else {
                print("✅ Veterinarians sync completed (no changes needed)")
            }
        }
    }
}
