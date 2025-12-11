//
//  RealtimeService.swift
//  LilyHillFarm
//
//  Service for managing Supabase Realtime subscriptions
//  Listens for server-side changes and updates Core Data in real-time
//

import Foundation
internal import CoreData
import Supabase
import Combine

@MainActor
class RealtimeService: ObservableObject {
    private let context: NSManagedObjectContext
    private let supabase = SupabaseManager.shared

    @Published var isConnected = false
    @Published var connectionError: String?

    private var cattleChannel: RealtimeChannelV2?
    private var healthRecordsChannel: RealtimeChannelV2?
    private var pregnancyRecordsChannel: RealtimeChannelV2?
    private var calvingRecordsChannel: RealtimeChannelV2?
    private var tasksChannel: RealtimeChannelV2?

    private var subscriptionTasks: [_Concurrency.Task<Void, Error>] = []

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Subscription Management

    /// Start all realtime subscriptions
    func startSubscriptions() async {
        print("🔴 REALTIME: Starting subscriptions...")

        do {
            let farmId = try await getFarmId()
            print("🔴 REALTIME: Got farm_id: \(farmId)")

            // Subscribe to key tables
            await subscribeToCattle(farmId: farmId)
            await subscribeToHealthRecords(farmId: farmId)
            await subscribeToPregnancyRecords(farmId: farmId)
            await subscribeToCalvingRecords(farmId: farmId)
            await subscribeToTasks(farmId: farmId)

            isConnected = true
            print("✅ REALTIME: All subscriptions started successfully")
        } catch {
            print("❌ REALTIME: Failed to start subscriptions: \(error)")
            connectionError = error.localizedDescription
        }
    }

    /// Stop all realtime subscriptions
    func stopSubscriptions() async {
        print("🔴 Stopping realtime subscriptions...")

        // Cancel all subscription tasks
        for task in subscriptionTasks {
            task.cancel()
        }
        subscriptionTasks.removeAll()

        // Remove channels
        if let channel = cattleChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = healthRecordsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = pregnancyRecordsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = calvingRecordsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = tasksChannel {
            await supabase.client.removeChannel(channel)
        }

        cattleChannel = nil
        healthRecordsChannel = nil
        pregnancyRecordsChannel = nil
        calvingRecordsChannel = nil
        tasksChannel = nil

        isConnected = false
        print("✅ Realtime subscriptions stopped")
    }

    // MARK: - Cattle Subscriptions

    private func subscribeToCattle(farmId: UUID) async {
        print("🔴 REALTIME: Subscribing to cattle table for farm \(farmId)...")

        let channel = supabase.client.channel("cattle-\(farmId)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "cattle",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        print("🔴 REALTIME: Calling subscribe() on cattle channel...")
        await channel.subscribe()
        cattleChannel = channel
        print("🔴 REALTIME: Cattle channel subscribed")

        let task = _Concurrency.Task {
            print("🔴 REALTIME: Cattle stream task started, waiting for changes...")
            for try await change in changeStream {
                print("📥 REALTIME: Cattle change received!")
                await handleCattleChange(change)
            }
            print("🔴 REALTIME: Cattle stream ended")
        }
        subscriptionTasks.append(task)

        print("✅ REALTIME: Cattle subscription complete")
    }

    private func handleCattleChange(_ change: AnyAction) async {
        // Temporarily disable auto-sync to prevent echo
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        switch change {
        case .insert(let action):
            print("📥 Realtime: Cattle inserted")
            await insertCattle(from: action.record)

        case .update(let action):
            print("📥 Realtime: Cattle updated")
            await updateCattle(from: action.record)

        case .delete(let action):
            print("📥 Realtime: Cattle deleted")
            await deleteCattle(from: action.oldRecord)
        }
    }

    private func insertCattle(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.stringValue,
              let id = UUID(uuidString: idString) else {
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            // Check if already exists
            let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            if (try? self.context.fetch(fetchRequest).first) != nil {
                print("   ⚠️ Cattle \(id) already exists, skipping insert")
                return
            }

            // Create new cattle
            let cattle = Cattle(context: self.context)
            self.updateCattleFromRecordSync(cattle, record: record)

            try? self.context.save()
            print("   ✅ Inserted cattle \(id)")
        }
    }

    private func updateCattle(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.stringValue,
              let id = UUID(uuidString: idString) else {
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let cattle = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Cattle \(id) not found for update")
                return
            }

            self.updateCattleFromRecordSync(cattle, record: record)

            try? self.context.save()
            print("   ✅ Updated cattle \(id)")
        }
    }

    private func deleteCattle(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.stringValue,
              let id = UUID(uuidString: idString) else {
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let cattle = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Cattle \(id) not found for delete")
                return
            }

            cattle.deletedAt = Date()

            try? self.context.save()
            print("   ✅ Soft deleted cattle \(id)")
        }
    }

    nonisolated private func updateCattleFromRecordSync(_ cattle: Cattle, record: [String: AnyJSON]) {
        if let idString = record["id"]?.stringValue {
            cattle.id = UUID(uuidString: idString)
        }
        if let tagNumber = record["tag_number"]?.stringValue {
            cattle.tagNumber = tagNumber
        }
        if let name = record["name"]?.stringValue {
            cattle.name = name
        }
        if let sex = record["sex"]?.stringValue {
            cattle.sex = sex
        }
        if let cattleType = record["cattle_type"]?.stringValue {
            cattle.cattleType = cattleType
        }
        if let currentStage = record["current_stage"]?.stringValue {
            cattle.currentStage = currentStage
        }
        if let currentStatus = record["current_status"]?.stringValue {
            cattle.currentStatus = currentStatus
        }
        if let farmIdString = record["farm_id"]?.stringValue {
            cattle.farmId = UUID(uuidString: farmIdString)
        }

        // Resolve breed relationship
        if let breedIdString = record["breed_id"]?.stringValue,
           let breedId = UUID(uuidString: breedIdString) {
            let breedFetch: NSFetchRequest<Breed> = Breed.fetchRequest()
            breedFetch.predicate = NSPredicate(format: "id == %@", breedId as CVarArg)
            cattle.breed = try? context.fetch(breedFetch).first
        }
    }

    // MARK: - Health Records Subscriptions

    private func subscribeToHealthRecords(farmId: UUID) async {
        // Get cattle IDs for this farm
        let cattleIds = await getCattleIds(for: farmId)
        guard !cattleIds.isEmpty else {
            print("⚠️ No cattle found for health records subscription")
            return
        }

        let channel = supabase.client.channel("health-records-\(farmId)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "health_records"
        )

        await channel.subscribe()
        healthRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleHealthRecordChange(change, cattleIds: cattleIds)
            }
        }
        subscriptionTasks.append(task)

        print("✅ Subscribed to health record changes")
    }

    private func handleHealthRecordChange(_ change: AnyAction, cattleIds: [UUID]) async {
        // Filter to only our farm's cattle
        let record: [String: AnyJSON]
        switch change {
        case .insert(let action):
            record = action.record
        case .update(let action):
            record = action.record
        case .delete(let action):
            record = action.oldRecord
        }

        guard let cattleIdString = record["cattle_id"]?.stringValue,
              let cattleId = UUID(uuidString: cattleIdString),
              cattleIds.contains(cattleId) else {
            return
        }

        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        switch change {
        case .insert:
            print("📥 Realtime: Health record inserted")
        case .update:
            print("📥 Realtime: Health record updated")
        case .delete:
            print("📥 Realtime: Health record deleted")
        }

        // Trigger a health records sync for this cattle
        // (Full implementation would mirror cattle logic above)
    }

    // MARK: - Pregnancy Records Subscriptions

    private func subscribeToPregnancyRecords(farmId: UUID) async {
        let cattleIds = await getCattleIds(for: farmId)
        guard !cattleIds.isEmpty else { return }

        let channel = supabase.client.channel("pregnancy-records-\(farmId)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "pregnancy_records"
        )

        await channel.subscribe()
        pregnancyRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handlePregnancyRecordChange(change, cattleIds: cattleIds)
            }
        }
        subscriptionTasks.append(task)

        print("✅ Subscribed to pregnancy record changes")
    }

    private func handlePregnancyRecordChange(_ change: AnyAction, cattleIds: [UUID]) async {
        let record: [String: AnyJSON]
        switch change {
        case .insert(let action):
            record = action.record
        case .update(let action):
            record = action.record
        case .delete(let action):
            record = action.oldRecord
        }

        guard let cowIdString = record["cow_id"]?.stringValue,
              let cowId = UUID(uuidString: cowIdString),
              cattleIds.contains(cowId) else {
            return
        }

        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Pregnancy record changed")
    }

    // MARK: - Calving Records Subscriptions

    private func subscribeToCalvingRecords(farmId: UUID) async {
        let cattleIds = await getCattleIds(for: farmId)
        guard !cattleIds.isEmpty else { return }

        let channel = supabase.client.channel("calving-records-\(farmId)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "calving_records"
        )

        await channel.subscribe()
        calvingRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleCalvingRecordChange(change, cattleIds: cattleIds)
            }
        }
        subscriptionTasks.append(task)

        print("✅ Subscribed to calving record changes")
    }

    private func handleCalvingRecordChange(_ change: AnyAction, cattleIds: [UUID]) async {
        let record: [String: AnyJSON]
        switch change {
        case .insert(let action):
            record = action.record
        case .update(let action):
            record = action.record
        case .delete(let action):
            record = action.oldRecord
        }

        guard let damIdString = record["dam_id"]?.stringValue,
              let damId = UUID(uuidString: damIdString),
              cattleIds.contains(damId) else {
            return
        }

        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Calving record changed")
    }

    // MARK: - Tasks Subscriptions

    private func subscribeToTasks(farmId: UUID) async {
        let channel = supabase.client.channel("tasks-\(farmId)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "tasks",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        tasksChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleTaskChange(change)
            }
        }
        subscriptionTasks.append(task)

        print("✅ Subscribed to task changes")
    }

    private func handleTaskChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Task changed")
    }

    // MARK: - Helper Methods

    private func getFarmId() async throws -> UUID {
        guard let userId = supabase.userId else {
            throw RepositoryError.notAuthenticated
        }

        struct FarmUser: Codable {
            let farm_id: UUID
        }

        let farmUsers: [FarmUser] = try await supabase.client
            .from("farm_users")
            .select("farm_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let farmId = farmUsers.first?.farm_id else {
            throw RepositoryError.invalidData
        }

        return farmId
    }

    private func getCattleIds(for farmId: UUID) async -> [UUID] {
        await context.perform { [weak self] in
            guard let self = self else { return [] }

            let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)
            fetchRequest.propertiesToFetch = ["id"]

            guard let cattle = try? self.context.fetch(fetchRequest) else {
                return []
            }

            return cattle.compactMap { $0.id }
        }
    }
}
