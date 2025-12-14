//
//  MedicationRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Medications with Supabase
//

import Foundation
internal import CoreData
import Supabase

class MedicationRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all medications from Supabase for current farm
    func fetchAll() async throws -> [MedicationDTO] {
        try requireAuth()
        let farmId = try await getFarmId()

        let medications: [MedicationDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.medications)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("name")
            .execute()
            .value

        return medications
    }

    // MARK: - Sync

    /// Sync medications: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        print("🔄 Fetching medications from Supabase...")
        let medicationDTOs = try await fetchAll()
        print("✅ Fetched \(medicationDTOs.count) medications from Supabase")

        // Get farmId outside of perform block
        let farmId = try await getFarmId()

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(medicationDTOs.count) medications to Core Data...")

            let supabaseIds = Set(medicationDTOs.map { $0.id })

            let fetchRequest: NSFetchRequest<Medication> = Medication.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@", farmId as CVarArg)
            let allLocalMedications = try self.context.fetch(fetchRequest)

            for localMedication in allLocalMedications {
                guard let localId = localMedication.id else {
                    self.context.delete(localMedication)
                    continue
                }
                if !supabaseIds.contains(localId) {
                    self.context.delete(localMedication)
                    print("   🗑️ Deleted medication \(localMedication.name ?? "unknown")")
                }
            }

            for dto in medicationDTOs {
                let fetchRequest: NSFetchRequest<Medication> = Medication.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                fetchRequest.fetchLimit = 1

                let medication: Medication
                if let existing = try self.context.fetch(fetchRequest).first {
                    medication = existing
                } else {
                    medication = Medication(context: self.context)
                }

                dto.update(medication)
            }

            if self.context.hasChanges {
                print("💾 Saving medications to Core Data...")
                try self.saveContext()
                print("✅ Medications sync completed!")
            } else {
                print("✅ Medications sync completed (no changes needed)")
            }
        }
    }
}
