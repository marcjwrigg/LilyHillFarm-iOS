//
//  ProcessorRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Processors with Supabase
//

import Foundation
internal import CoreData
import Supabase

class ProcessorRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all processors from Supabase for current farm
    func fetchAll() async throws -> [ProcessorDTO] {
        try requireAuth()
        let farmId = try await getFarmId()

        let processors: [ProcessorDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.processors)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("name")
            .execute()
            .value

        return processors
    }

    // MARK: - Sync

    /// Sync processors: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching processors from Supabase...")
        let processorDTOs = try await fetchAll()
        print("✅ Fetched \(processorDTOs.count) processors from Supabase")

        // Get farmId BEFORE context.perform
        let farmId = try await getFarmId()

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(processorDTOs.count) processors to Core Data...")

            let supabaseIds = Set(processorDTOs.map { $0.id })

            let fetchRequest: NSFetchRequest<Processor> = Processor.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@", farmId as CVarArg)
            let allLocalProcessors = try self.context.fetch(fetchRequest)

            for localProcessor in allLocalProcessors {
                guard let localId = localProcessor.id else {
                    self.context.delete(localProcessor)
                    continue
                }
                if !supabaseIds.contains(localId) {
                    self.context.delete(localProcessor)
                    print("   🗑️ Deleted processor \(localProcessor.name ?? "unknown")")
                }
            }

            for dto in processorDTOs {
                let fetchRequest: NSFetchRequest<Processor> = Processor.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let processor: Processor
                if let existing = try self.context.fetch(fetchRequest).first {
                    processor = existing
                } else {
                    processor = Processor(context: self.context)
                }

                dto.update(processor)
            }

            if self.context.hasChanges {
                print("💾 Saving processors to Core Data...")
                try self.saveContext()
                print("✅ Processors sync completed!")
            } else {
                print("✅ Processors sync completed (no changes needed)")
            }
        }
    }
}
