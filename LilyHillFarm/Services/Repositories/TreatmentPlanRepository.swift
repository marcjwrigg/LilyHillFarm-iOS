//
//  TreatmentPlanRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Treatment Plans with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class TreatmentPlanRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all treatment plans from Supabase
    func fetchAll() async throws -> [TreatmentPlanDTO] {
        try requireAuth()

        let farmId = try await getFarmId()

        let plans: [TreatmentPlanDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.treatmentPlans)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("name", ascending: true)
            .execute()
            .value

        return plans
    }

    /// Fetch treatment plan by ID
    func fetchById(_ id: UUID) async throws -> TreatmentPlanDTO? {
        try requireAuth()

        let farmId = try await getFarmId()

        let plan: TreatmentPlanDTO? = try await supabase.client
            .from(SupabaseConfig.Tables.treatmentPlans)
            .select()
            .eq("id", value: id.uuidString)
            .eq("farm_id", value: farmId.uuidString)
            .single()
            .execute()
            .value

        return plan
    }

    // MARK: - Sync

    /// Sync all treatment plans from Supabase to Core Data
    func syncFromSupabase() async throws {
        try requireAuth()

        // Treatment plans are reference data that rarely change
        // Only sync if it's been more than 24 hours since last sync
        let tableName = SupabaseConfig.Tables.treatmentPlans
        if let lastSync = getLastSyncDate(for: tableName) {
            let hoursSinceLastSync = Date().timeIntervalSince(lastSync) / 3600
            if hoursSinceLastSync < 24 {
                print("⏭️ Skipping treatment plans sync (last synced \(String(format: "%.1f", hoursSinceLastSync)) hours ago)")
                return
            }
        }

        print("🔄 Fetching treatment plans from Supabase...")
        let planDTOs = try await fetchAll()
        print("✅ Fetched \(planDTOs.count) treatment plans from Supabase")

        try await context.perform { [weak self] in
            guard let self = self else { return }

            for dto in planDTOs {
                print("   📋 Processing treatment plan: \(dto.name) (ID: \(dto.id.uuidString))")

                // Try to find existing plan
                let fetchRequest: NSFetchRequest<TreatmentPlan> = TreatmentPlan.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                let results = try self.context.fetch(fetchRequest)

                let plan: TreatmentPlan
                if let existing = results.first {
                    plan = existing
                    print("      ↺ Updating existing plan")
                } else {
                    plan = TreatmentPlan(context: self.context)
                    print("      ✨ Creating new plan")
                }

                // Update from DTO
                dto.update(plan)
                print("      ✅ Saved: \(plan.name ?? "unnamed") with ID: \(plan.id?.uuidString ?? "no id")")
            }

            // Only save if there are actual changes
            if self.context.hasChanges {
                print("💾 Saving treatment plans to Core Data...")
                try self.saveContext()
                print("✅ Treatment plans sync completed!")
            } else {
                print("✅ Treatment plans sync completed (no changes needed)")
            }
        }

        // Update last sync date
        setLastSyncDate(Date(), for: tableName)
    }
}
