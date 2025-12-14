//
//  TreatmentPlanStepRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Treatment Plan Steps with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class TreatmentPlanStepRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all treatment plan steps from Supabase (filtered to user's farm)
    func fetchAll() async throws -> [TreatmentPlanStepDTO] {
        try requireAuth()

        let farmId = try await getFarmId()

        // First, get all treatment plan IDs for this farm
        struct PlanIdResponse: Codable {
            let id: UUID
        }

        let planIdResponses: [PlanIdResponse] = try await supabase.client
            .from(SupabaseConfig.Tables.treatmentPlans)
            .select("id")
            .eq("farm_id", value: farmId.uuidString)
            .execute()
            .value

        let planIds = planIdResponses.map { $0.id.uuidString }

        print("📋 Fetching steps for \(planIds.count) treatment plans")

        // If no plans, return empty array
        guard !planIds.isEmpty else {
            print("⚠️ No treatment plans found for farm, returning empty steps array")
            return []
        }

        // Fetch steps only for these treatment plan IDs
        let steps: [TreatmentPlanStepDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.treatmentPlanSteps)
            .select()
            .in("treatment_plan_id", values: planIds)
            .order("step_number", ascending: true)
            .execute()
            .value

        print("📋 Fetched \(steps.count) treatment plan steps for farm")

        return steps
    }

    /// Fetch treatment plan steps by treatment plan ID
    func fetchByTreatmentPlan(_ treatmentPlanId: UUID) async throws -> [TreatmentPlanStepDTO] {
        try requireAuth()

        let steps: [TreatmentPlanStepDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.treatmentPlanSteps)
            .select()
            .eq("treatment_plan_id", value: treatmentPlanId.uuidString)
            .order("step_number", ascending: true)
            .execute()
            .value

        return steps
    }

    // MARK: - Sync

    /// Sync all treatment plan steps from Supabase to Core Data
    func syncFromSupabase() async throws {
        try requireAuth()

        // Treatment plan steps are reference data that rarely change
        // Only sync if it's been more than 24 hours since last sync
        let tableName = SupabaseConfig.Tables.treatmentPlanSteps
        if let lastSync = getLastSyncDate(for: tableName) {
            let hoursSinceLastSync = Date().timeIntervalSince(lastSync) / 3600
            if hoursSinceLastSync < 24 {
                print("⏭️ Skipping treatment plan steps sync (last synced \(String(format: "%.1f", hoursSinceLastSync)) hours ago)")
                return
            }
        }

        print("🔄 Fetching treatment plan steps from Supabase...")
        let stepDTOs = try await fetchAll()
        print("✅ Fetched \(stepDTOs.count) treatment plan steps from Supabase")

        try await context.perform { [weak self] in
            guard let self = self else { return }

            for dto in stepDTOs {
                // Try to find existing step
                let fetchRequest: NSFetchRequest<TreatmentPlanStep> = TreatmentPlanStep.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                let results = try self.context.fetch(fetchRequest)

                let step: TreatmentPlanStep
                if let existing = results.first {
                    step = existing
                } else {
                    step = TreatmentPlanStep(context: self.context)
                }

                // Update from DTO
                dto.update(step)

                // Find and set treatment plan relationship
                let planFetchRequest: NSFetchRequest<TreatmentPlan> = TreatmentPlan.fetchRequest()
                planFetchRequest.predicate = NSPredicate(format: "id == %@", dto.treatmentPlanId as CVarArg)

                if let plan = try self.context.fetch(planFetchRequest).first {
                    step.treatmentPlan = plan
                }
            }

            // Only save if there are actual changes
            if self.context.hasChanges {
                print("💾 Saving treatment plan steps to Core Data...")
                try self.saveContext()
                print("✅ Treatment plan steps sync completed!")
            } else {
                print("✅ Treatment plan steps sync completed (no changes needed)")
            }
        }

        // Update last sync date
        setLastSyncDate(Date(), for: tableName)
    }
}
