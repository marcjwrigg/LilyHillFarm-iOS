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
    private var saleRecordsChannel: RealtimeChannelV2?
    private var processingRecordsChannel: RealtimeChannelV2?
    private var mortalityRecordsChannel: RealtimeChannelV2?
    private var stageTransitionsChannel: RealtimeChannelV2?
    private var photosChannel: RealtimeChannelV2?
    private var contactsChannel: RealtimeChannelV2?
    private var pasturesChannel: RealtimeChannelV2?
    private var pastureLogsChannel: RealtimeChannelV2?
    private var documentsChannel: RealtimeChannelV2?
    private var cattleStagesChannel: RealtimeChannelV2?
    private var healthConditionsChannel: RealtimeChannelV2?
    private var healthRecordTypesChannel: RealtimeChannelV2?
    private var processorsChannel: RealtimeChannelV2?
    private var veterinariansChannel: RealtimeChannelV2?
    private var productionPathsChannel: RealtimeChannelV2?
    private var productionPathStagesChannel: RealtimeChannelV2?
    private var treatmentPlansChannel: RealtimeChannelV2?
    private var treatmentPlanStepsChannel: RealtimeChannelV2?
    private var contactEmailsChannel: RealtimeChannelV2?
    private var contactPhoneNumbersChannel: RealtimeChannelV2?
    private var contactPersonsChannel: RealtimeChannelV2?

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

            // Subscribe to all tables in parallel for fastest startup
            async let cattle = subscribeToCattle(farmId: farmId)
            async let healthRecords = subscribeToHealthRecords(farmId: farmId)
            async let pregnancyRecords = subscribeToPregnancyRecords(farmId: farmId)
            async let calvingRecords = subscribeToCalvingRecords(farmId: farmId)
            async let saleRecords = subscribeToSaleRecords(farmId: farmId)
            async let processingRecords = subscribeToProcessingRecords(farmId: farmId)
            async let mortalityRecords = subscribeToMortalityRecords(farmId: farmId)
            async let stageTransitions = subscribeToStageTransitions(farmId: farmId)
            async let photos = subscribeToPhotos(farmId: farmId)
            async let contacts = subscribeToContacts(farmId: farmId)
            async let contactEmails = subscribeToContactEmails(farmId: farmId)
            async let contactPhoneNumbers = subscribeToContactPhoneNumbers(farmId: farmId)
            async let contactPersons = subscribeToContactPersons(farmId: farmId)
            async let tasks = subscribeToTasks(farmId: farmId)
            async let pastures = subscribeToPastures(farmId: farmId)
            async let pastureLogs = subscribeToPastureLogs(farmId: farmId)
            async let documents = subscribeToDocuments(farmId: farmId)
            async let cattleStages = subscribeToCattleStages(farmId: farmId)
            async let healthConditions = subscribeToHealthConditions(farmId: farmId)
            async let healthRecordTypes = subscribeToHealthRecordTypes(farmId: farmId)
            async let processors = subscribeToProcessors(farmId: farmId)
            async let veterinarians = subscribeToVeterinarians(farmId: farmId)
            async let productionPaths = subscribeToProductionPaths(farmId: farmId)
            async let productionPathStages = subscribeToProductionPathStages(farmId: farmId)
            async let treatmentPlans = subscribeToTreatmentPlans(farmId: farmId)
            async let treatmentPlanSteps = subscribeToTreatmentPlanSteps(farmId: farmId)

            // Wait for all subscriptions to complete
            _ = await (cattle, healthRecords, pregnancyRecords, calvingRecords, saleRecords,
                      processingRecords, mortalityRecords, stageTransitions, photos, contacts,
                      contactEmails, contactPhoneNumbers, contactPersons, tasks, pastures,
                      pastureLogs, documents, cattleStages, healthConditions, healthRecordTypes,
                      processors, veterinarians, productionPaths, productionPathStages,
                      treatmentPlans, treatmentPlanSteps)

            isConnected = true
            print("✅ REALTIME: All 27 subscriptions started in parallel")
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
        if let channel = saleRecordsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = processingRecordsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = mortalityRecordsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = stageTransitionsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = photosChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = contactsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = tasksChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = pasturesChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = pastureLogsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = documentsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = cattleStagesChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = healthConditionsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = healthRecordTypesChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = processorsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = veterinariansChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = productionPathsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = productionPathStagesChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = treatmentPlansChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = treatmentPlanStepsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = contactEmailsChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = contactPhoneNumbersChannel {
            await supabase.client.removeChannel(channel)
        }
        if let channel = contactPersonsChannel {
            await supabase.client.removeChannel(channel)
        }

        cattleChannel = nil
        healthRecordsChannel = nil
        pregnancyRecordsChannel = nil
        calvingRecordsChannel = nil
        saleRecordsChannel = nil
        processingRecordsChannel = nil
        mortalityRecordsChannel = nil
        stageTransitionsChannel = nil
        photosChannel = nil
        contactsChannel = nil
        tasksChannel = nil
        pasturesChannel = nil
        pastureLogsChannel = nil
        documentsChannel = nil
        cattleStagesChannel = nil
        healthConditionsChannel = nil
        healthRecordTypesChannel = nil
        processorsChannel = nil
        veterinariansChannel = nil
        productionPathsChannel = nil
        productionPathStagesChannel = nil
        treatmentPlansChannel = nil
        treatmentPlanStepsChannel = nil
        contactEmailsChannel = nil
        contactPhoneNumbersChannel = nil
        contactPersonsChannel = nil

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
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(CattleDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode cattle DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            // Check if already exists
            let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

            if (try? self.context.fetch(fetchRequest).first) != nil {
                print("   ⚠️ Cattle \(dto.id) already exists, skipping insert")
                return
            }

            // Create new cattle
            let cattle = Cattle(context: self.context)
            dto.update(cattle)

            // Resolve relationships
            self.resolveRelationships(for: cattle, dto: dto)

            try? self.context.save()
            print("   ✅ Inserted cattle \(dto.id)")
        }
    }

    private func updateCattle(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(CattleDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode cattle DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

            guard let cattle = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Cattle \(dto.id) not found for update")
                return
            }

            dto.update(cattle)

            // Resolve relationships
            self.resolveRelationships(for: cattle, dto: dto)

            try? self.context.save()
            print("   ✅ Updated cattle \(dto.id)")
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

    nonisolated private func resolveRelationships(for cattle: Cattle, dto: CattleDTO) {
        // Resolve breed relationship
        if let breedId = dto.breedId {
            let breedFetch: NSFetchRequest<Breed> = Breed.fetchRequest()
            breedFetch.predicate = NSPredicate(format: "id == %@", breedId as CVarArg)
            cattle.breed = try? context.fetch(breedFetch).first
        }

        // Resolve dam relationship
        if let damId = dto.damId {
            let damFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            damFetch.predicate = NSPredicate(format: "id == %@", damId as CVarArg)
            cattle.dam = try? context.fetch(damFetch).first
        }

        // Resolve sire relationship
        if let sireId = dto.sireId {
            let sireFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            sireFetch.predicate = NSPredicate(format: "id == %@", sireId as CVarArg)
            cattle.sire = try? context.fetch(sireFetch).first
        }
    }

    // MARK: - Health Records Subscriptions

    private func subscribeToHealthRecords(farmId: UUID) async {
        let channel = supabase.client.channel("health-records-\(farmId)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "health_records",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        healthRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleHealthRecordChange(change)
            }
        }
        subscriptionTasks.append(task)

        print("✅ Subscribed to health record changes")
    }

    private func handleHealthRecordChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        switch change {
        case .insert(let action):
            print("📥 Realtime: Health record inserted")
            await insertHealthRecord(from: action.record)
        case .update(let action):
            print("📥 Realtime: Health record updated")
            await updateHealthRecord(from: action.record)
        case .delete(let action):
            print("📥 Realtime: Health record deleted")
            await deleteHealthRecord(from: action.oldRecord)
        }
    }

    private func insertHealthRecord(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(HealthRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode health record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

            if (try? self.context.fetch(fetchRequest).first) != nil {
                print("   ⚠️ Health record \(dto.id) already exists")
                return
            }

            let healthRecord = HealthRecord(context: self.context)
            dto.update(healthRecord)

            // Resolve cattle relationship
            if let cattleId = dto.cattleId {
                let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                healthRecord.cattle = try? self.context.fetch(cattleFetch).first
            }

            try? self.context.save()
            print("   ✅ Inserted health record \(dto.id)")
        }
    }

    private func updateHealthRecord(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(HealthRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode health record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

            guard let healthRecord = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Health record \(dto.id) not found")
                return
            }

            dto.update(healthRecord)

            // Resolve cattle relationship
            if let cattleId = dto.cattleId {
                let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                healthRecord.cattle = try? self.context.fetch(cattleFetch).first
            }

            try? self.context.save()
            print("   ✅ Updated health record \(dto.id)")
        }
    }

    private func deleteHealthRecord(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.stringValue,
              let id = UUID(uuidString: idString) else {
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let healthRecord = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Health record \(id) not found")
                return
            }

            healthRecord.deletedAt = Date()
            try? self.context.save()
            print("   ✅ Soft deleted health record \(id)")
        }
    }

    // MARK: - Pregnancy Records Subscriptions

    private func subscribeToPregnancyRecords(farmId: UUID) async {
        let channel = supabase.client.channel("pregnancy-records-\(farmId)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "pregnancy_records",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        pregnancyRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handlePregnancyRecordChange(change)
            }
        }
        subscriptionTasks.append(task)

        print("✅ Subscribed to pregnancy record changes")
    }

    private func handlePregnancyRecordChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        switch change {
        case .insert(let action):
            print("📥 Realtime: Pregnancy record inserted")
            await insertPregnancyRecord(from: action.record)
        case .update(let action):
            print("📥 Realtime: Pregnancy record updated")
            await updatePregnancyRecord(from: action.record)
        case .delete(let action):
            print("📥 Realtime: Pregnancy record deleted")
            await deletePregnancyRecord(from: action.oldRecord)
        }
    }

    private func insertPregnancyRecord(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(PregnancyRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode pregnancy record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

            if (try? self.context.fetch(fetchRequest).first) != nil {
                print("   ⚠️ Pregnancy record \(dto.id) already exists")
                return
            }

            let pregnancyRecord = PregnancyRecord(context: self.context)
            dto.update(pregnancyRecord)

            // Resolve relationships
            let cowFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            cowFetch.predicate = NSPredicate(format: "id == %@", dto.damId as CVarArg)
            pregnancyRecord.cow = try? self.context.fetch(cowFetch).first

            if let sireId = dto.sireId {
                let sireFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                sireFetch.predicate = NSPredicate(format: "id == %@", sireId as CVarArg)
                pregnancyRecord.bull = try? self.context.fetch(sireFetch).first
            }

            try? self.context.save()
            print("   ✅ Inserted pregnancy record \(dto.id)")
        }
    }

    private func updatePregnancyRecord(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(PregnancyRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode pregnancy record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

            guard let pregnancyRecord = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Pregnancy record \(dto.id) not found")
                return
            }

            dto.update(pregnancyRecord)

            // Resolve relationships
            let cowFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            cowFetch.predicate = NSPredicate(format: "id == %@", dto.damId as CVarArg)
            pregnancyRecord.cow = try? self.context.fetch(cowFetch).first

            if let sireId = dto.sireId {
                let sireFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                sireFetch.predicate = NSPredicate(format: "id == %@", sireId as CVarArg)
                pregnancyRecord.bull = try? self.context.fetch(sireFetch).first
            }

            try? self.context.save()
            print("   ✅ Updated pregnancy record \(dto.id)")
        }
    }

    private func deletePregnancyRecord(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.stringValue,
              let id = UUID(uuidString: idString) else {
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let pregnancyRecord = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Pregnancy record \(id) not found")
                return
            }

            pregnancyRecord.deletedAt = Date()
            try? self.context.save()
            print("   ✅ Soft deleted pregnancy record \(id)")
        }
    }

    // MARK: - Calving Records Subscriptions

    private func subscribeToCalvingRecords(farmId: UUID) async {
        let channel = supabase.client.channel("calving-records-\(farmId)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "calving_records",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        calvingRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleCalvingRecordChange(change)
            }
        }
        subscriptionTasks.append(task)

        print("✅ Subscribed to calving record changes")
    }

    private func handleCalvingRecordChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        switch change {
        case .insert(let action):
            print("📥 Realtime: Calving record inserted")
            await insertCalvingRecord(from: action.record)
        case .update(let action):
            print("📥 Realtime: Calving record updated")
            await updateCalvingRecord(from: action.record)
        case .delete(let action):
            print("📥 Realtime: Calving record deleted")
            await deleteCalvingRecord(from: action.oldRecord)
        }
    }

    private func insertCalvingRecord(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(CalvingRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode calving record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

            if (try? self.context.fetch(fetchRequest).first) != nil {
                print("   ⚠️ Calving record \(dto.id) already exists")
                return
            }

            let calvingRecord = CalvingRecord(context: self.context)
            dto.update(calvingRecord)

            // Resolve relationships
            let damFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            damFetch.predicate = NSPredicate(format: "id == %@", dto.damId as CVarArg)
            calvingRecord.dam = try? self.context.fetch(damFetch).first

            if let sireId = dto.sireId {
                let sireFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                sireFetch.predicate = NSPredicate(format: "id == %@", sireId as CVarArg)
                calvingRecord.sire = try? self.context.fetch(sireFetch).first
            }

            if let calfId = dto.calfId {
                let calfFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                calfFetch.predicate = NSPredicate(format: "id == %@", calfId as CVarArg)
                calvingRecord.calf = try? self.context.fetch(calfFetch).first
            }

            try? self.context.save()
            print("   ✅ Inserted calving record \(dto.id)")
        }
    }

    private func updateCalvingRecord(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(CalvingRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode calving record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

            guard let calvingRecord = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Calving record \(dto.id) not found")
                return
            }

            dto.update(calvingRecord)

            // Resolve relationships
            let damFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            damFetch.predicate = NSPredicate(format: "id == %@", dto.damId as CVarArg)
            calvingRecord.dam = try? self.context.fetch(damFetch).first

            if let sireId = dto.sireId {
                let sireFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                sireFetch.predicate = NSPredicate(format: "id == %@", sireId as CVarArg)
                calvingRecord.sire = try? self.context.fetch(sireFetch).first
            }

            if let calfId = dto.calfId {
                let calfFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                calfFetch.predicate = NSPredicate(format: "id == %@", calfId as CVarArg)
                calvingRecord.calf = try? self.context.fetch(calfFetch).first
            }

            try? self.context.save()
            print("   ✅ Updated calving record \(dto.id)")
        }
    }

    private func deleteCalvingRecord(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.stringValue,
              let id = UUID(uuidString: idString) else {
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let calvingRecord = try? self.context.fetch(fetchRequest).first else {
                print("   ⚠️ Calving record \(id) not found")
                return
            }

            calvingRecord.deletedAt = Date()
            try? self.context.save()
            print("   ✅ Soft deleted calving record \(id)")
        }
    }

    // MARK: - Sale Records Subscriptions

    private func subscribeToSaleRecords(farmId: UUID) async {
        let channel = supabase.client.channel("sale-records-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "sale_records",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        saleRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleSaleRecordChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to sale record changes")
    }

    private func handleSaleRecordChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        let record: [String: AnyJSON]
        switch change {
        case .insert(let action): record = action.record
        case .update(let action): record = action.record
        case .delete(let action): record = action.oldRecord
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(SaleRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode sale record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            switch change {
            case .insert:
                let fetchRequest: NSFetchRequest<SaleRecord> = SaleRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if (try? self.context.fetch(fetchRequest).first) == nil {
                    let saleRecord = SaleRecord(context: self.context)
                    dto.update(saleRecord)

                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", dto.cattleId as CVarArg)
                    saleRecord.cattle = try? self.context.fetch(cattleFetch).first

                    try? self.context.save()
                    print("   ✅ Inserted sale record \(dto.id)")
                }

            case .update:
                let fetchRequest: NSFetchRequest<SaleRecord> = SaleRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let saleRecord = try? self.context.fetch(fetchRequest).first {
                    dto.update(saleRecord)
                    try? self.context.save()
                    print("   ✅ Updated sale record \(dto.id)")
                }

            case .delete:
                let fetchRequest: NSFetchRequest<SaleRecord> = SaleRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let saleRecord = try? self.context.fetch(fetchRequest).first {
                    saleRecord.deletedAt = Date()
                    try? self.context.save()
                    print("   ✅ Soft deleted sale record \(dto.id)")
                }
            }
        }
    }

    // MARK: - Processing Records Subscriptions

    private func subscribeToProcessingRecords(farmId: UUID) async {
        let channel = supabase.client.channel("processing-records-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "processing_records",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        processingRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleProcessingRecordChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to processing record changes")
    }

    private func handleProcessingRecordChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        let record: [String: AnyJSON]
        switch change {
        case .insert(let action): record = action.record
        case .update(let action): record = action.record
        case .delete(let action): record = action.oldRecord
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(ProcessingRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode processing record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            switch change {
            case .insert:
                let fetchRequest: NSFetchRequest<ProcessingRecord> = ProcessingRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if (try? self.context.fetch(fetchRequest).first) == nil {
                    let processingRecord = ProcessingRecord(context: self.context)
                    dto.update(processingRecord)

                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", dto.cattleId as CVarArg)
                    processingRecord.cattle = try? self.context.fetch(cattleFetch).first

                    try? self.context.save()
                    print("   ✅ Inserted processing record \(dto.id)")
                }

            case .update:
                let fetchRequest: NSFetchRequest<ProcessingRecord> = ProcessingRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let processingRecord = try? self.context.fetch(fetchRequest).first {
                    dto.update(processingRecord)
                    try? self.context.save()
                    print("   ✅ Updated processing record \(dto.id)")
                }

            case .delete:
                let fetchRequest: NSFetchRequest<ProcessingRecord> = ProcessingRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let processingRecord = try? self.context.fetch(fetchRequest).first {
                    processingRecord.deletedAt = Date()
                    try? self.context.save()
                    print("   ✅ Soft deleted processing record \(dto.id)")
                }
            }
        }
    }

    // MARK: - Mortality Records Subscriptions

    private func subscribeToMortalityRecords(farmId: UUID) async {
        let channel = supabase.client.channel("mortality-records-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "mortality_records",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        mortalityRecordsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleMortalityRecordChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to mortality record changes")
    }

    private func handleMortalityRecordChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        let record: [String: AnyJSON]
        switch change {
        case .insert(let action): record = action.record
        case .update(let action): record = action.record
        case .delete(let action): record = action.oldRecord
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(MortalityRecordDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode mortality record DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            switch change {
            case .insert:
                let fetchRequest: NSFetchRequest<MortalityRecord> = MortalityRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if (try? self.context.fetch(fetchRequest).first) == nil {
                    let mortalityRecord = MortalityRecord(context: self.context)
                    dto.update(mortalityRecord)

                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", dto.cattleId as CVarArg)
                    mortalityRecord.cattle = try? self.context.fetch(cattleFetch).first

                    try? self.context.save()
                    print("   ✅ Inserted mortality record \(dto.id)")
                }

            case .update:
                let fetchRequest: NSFetchRequest<MortalityRecord> = MortalityRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let mortalityRecord = try? self.context.fetch(fetchRequest).first {
                    dto.update(mortalityRecord)
                    try? self.context.save()
                    print("   ✅ Updated mortality record \(dto.id)")
                }

            case .delete:
                let fetchRequest: NSFetchRequest<MortalityRecord> = MortalityRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let mortalityRecord = try? self.context.fetch(fetchRequest).first {
                    // Note: mortality_records doesn't have deletedAt in schema
                    self.context.delete(mortalityRecord)
                    try? self.context.save()
                    print("   ✅ Deleted mortality record \(dto.id)")
                }
            }
        }
    }

    // MARK: - Stage Transitions Subscriptions

    private func subscribeToStageTransitions(farmId: UUID) async {
        let channel = supabase.client.channel("stage-transitions-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "stage_transitions",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        stageTransitionsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleStageTransitionChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to stage transition changes")
    }

    private func handleStageTransitionChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        let record: [String: AnyJSON]
        switch change {
        case .insert(let action): record = action.record
        case .update(let action): record = action.record
        case .delete(let action): record = action.oldRecord
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(StageTransitionDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode stage transition DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            switch change {
            case .insert:
                let fetchRequest: NSFetchRequest<StageTransition> = StageTransition.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if (try? self.context.fetch(fetchRequest).first) == nil {
                    let stageTransition = StageTransition(context: self.context)
                    dto.update(stageTransition)

                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", dto.cattleId as CVarArg)
                    stageTransition.cattle = try? self.context.fetch(cattleFetch).first

                    try? self.context.save()
                    print("   ✅ Inserted stage transition \(dto.id)")
                }

            case .update:
                let fetchRequest: NSFetchRequest<StageTransition> = StageTransition.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let stageTransition = try? self.context.fetch(fetchRequest).first {
                    dto.update(stageTransition)
                    try? self.context.save()
                    print("   ✅ Updated stage transition \(dto.id)")
                }

            case .delete:
                let fetchRequest: NSFetchRequest<StageTransition> = StageTransition.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let stageTransition = try? self.context.fetch(fetchRequest).first {
                    // Note: stage_transitions doesn't have deletedAt in schema
                    self.context.delete(stageTransition)
                    try? self.context.save()
                    print("   ✅ Deleted stage transition \(dto.id)")
                }
            }
        }
    }

    // MARK: - Photos Subscriptions

    private func subscribeToPhotos(farmId: UUID) async {
        let channel = supabase.client.channel("photos-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "photos",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        photosChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handlePhotoChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to photo changes")
    }

    private func handlePhotoChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        let record: [String: AnyJSON]
        switch change {
        case .insert(let action): record = action.record
        case .update(let action): record = action.record
        case .delete(let action): record = action.oldRecord
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(PhotoDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode photo DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            switch change {
            case .insert:
                let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if (try? self.context.fetch(fetchRequest).first) == nil {
                    let photo = Photo(context: self.context)
                    dto.update(photo)

                    if let cattleId = dto.cattleId {
                        let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                        cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                        photo.cattle = try? self.context.fetch(cattleFetch).first
                    }

                    try? self.context.save()
                    print("   ✅ Inserted photo \(dto.id)")
                }

            case .update:
                let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let photo = try? self.context.fetch(fetchRequest).first {
                    dto.update(photo)
                    try? self.context.save()
                    print("   ✅ Updated photo \(dto.id)")
                }

            case .delete:
                let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let photo = try? self.context.fetch(fetchRequest).first {
                    photo.deletedAt = Date()
                    try? self.context.save()
                    print("   ✅ Soft deleted photo \(dto.id)")
                }
            }
        }
    }

    // MARK: - Contacts Subscriptions

    private func subscribeToContacts(farmId: UUID) async {
        let channel = supabase.client.channel("contacts-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "contacts",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        contactsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleContactChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to contact changes")
    }

    private func handleContactChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        guard let record = (change as? AnyAction).map({ action -> [String: AnyJSON] in
            switch action {
            case .insert(let a): return a.record
            case .update(let a): return a.record
            case .delete(let a): return a.oldRecord
            }
        }),
        let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
        let dto = try? JSONDecoder().decode(ContactDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode contact DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            switch change {
            case .insert:
                let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if (try? self.context.fetch(fetchRequest).first) == nil {
                    let contact = Contact(context: self.context)
                    dto.update(contact)
                    try? self.context.save()
                    print("   ✅ Inserted contact \(dto.id)")
                }

            case .update:
                let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let contact = try? self.context.fetch(fetchRequest).first {
                    dto.update(contact)
                    try? self.context.save()
                    print("   ✅ Updated contact \(dto.id)")
                }

            case .delete:
                let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                if let contact = try? self.context.fetch(fetchRequest).first {
                    contact.deletedAt = Date()
                    try? self.context.save()
                    print("   ✅ Soft deleted contact \(dto.id)")
                }
            }
        }
    }

    // MARK: - Contact Emails Subscriptions

    private func subscribeToContactEmails(farmId: UUID) async {
        let contactIds = await getContactIds(for: farmId)
        guard !contactIds.isEmpty else { return }

        let channel = supabase.client.channel("contact-emails-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "contact_emails"
        )

        await channel.subscribe()
        contactEmailsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleContactEmailChange(change, contactIds: contactIds)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to contact email changes")
    }

    private func handleContactEmailChange(_ change: AnyAction, contactIds: [UUID]) async {
        let record: [String: AnyJSON]
        switch change {
        case .insert(let action): record = action.record
        case .update(let action): record = action.record
        case .delete(let action): record = action.oldRecord
        }

        guard let contactIdString = record["contact_id"]?.stringValue,
              let contactId = UUID(uuidString: contactIdString),
              contactIds.contains(contactId) else { return }

        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Contact email changed for contact \(contactId)")

        // Re-fetch all emails for this contact and update Core Data
        let repository = ContactRepository(context: context)
        do {
            let emails = try await repository.fetchEmails(for: contactId)

            try await context.perform { [weak self] in
                guard let self = self else { return }

                // Find the contact
                let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)

                guard let contact = try self.context.fetch(fetchRequest).first else {
                    print("⚠️ Contact not found: \(contactId)")
                    return
                }

                // Get existing emails
                let existingEmails = (contact.emails as? Set<ContactEmail>) ?? []
                let emailIds = Set(emails.map { $0.id })

                // Remove emails that no longer exist
                for email in existingEmails where !emailIds.contains(email.id!) {
                    self.context.delete(email)
                }

                // Add or update emails
                for dto in emails {
                    let email: ContactEmail
                    if let existing = existingEmails.first(where: { $0.id == dto.id }) {
                        email = existing
                    } else {
                        email = ContactEmail(context: self.context)
                        contact.addToEmails(email)
                    }
                    dto.update(email)
                    email.contact = contact
                }

                try self.context.save()
                print("✅ Updated \(emails.count) emails for contact \(contactId)")
            }
        } catch {
            print("❌ Failed to sync contact emails: \(error)")
        }
    }

    // MARK: - Contact Phone Numbers Subscriptions

    private func subscribeToContactPhoneNumbers(farmId: UUID) async {
        let contactIds = await getContactIds(for: farmId)
        guard !contactIds.isEmpty else { return }

        let channel = supabase.client.channel("contact-phone-numbers-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "contact_phone_numbers"
        )

        await channel.subscribe()
        contactPhoneNumbersChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleContactPhoneNumberChange(change, contactIds: contactIds)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to contact phone number changes")
    }

    private func handleContactPhoneNumberChange(_ change: AnyAction, contactIds: [UUID]) async {
        let record: [String: AnyJSON]
        switch change {
        case .insert(let action): record = action.record
        case .update(let action): record = action.record
        case .delete(let action): record = action.oldRecord
        }

        guard let contactIdString = record["contact_id"]?.stringValue,
              let contactId = UUID(uuidString: contactIdString),
              contactIds.contains(contactId) else { return }

        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Contact phone number changed for contact \(contactId)")

        // Re-fetch all phone numbers for this contact and update Core Data
        let repository = ContactRepository(context: context)
        do {
            let phoneNumbers = try await repository.fetchPhoneNumbers(for: contactId)

            try await context.perform { [weak self] in
                guard let self = self else { return }

                // Find the contact
                let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", contactId as CVarArg)

                guard let contact = try self.context.fetch(fetchRequest).first else {
                    print("⚠️ Contact not found: \(contactId)")
                    return
                }

                // Get existing phone numbers
                let existingPhoneNumbers = (contact.phoneNumbers as? Set<ContactPhoneNumber>) ?? []
                let phoneNumberIds = Set(phoneNumbers.map { $0.id })

                // Remove phone numbers that no longer exist
                for phoneNumber in existingPhoneNumbers where !phoneNumberIds.contains(phoneNumber.id!) {
                    self.context.delete(phoneNumber)
                }

                // Add or update phone numbers
                for dto in phoneNumbers {
                    let phoneNumber: ContactPhoneNumber
                    if let existing = existingPhoneNumbers.first(where: { $0.id == dto.id }) {
                        phoneNumber = existing
                    } else {
                        phoneNumber = ContactPhoneNumber(context: self.context)
                        contact.addToPhoneNumbers(phoneNumber)
                    }
                    dto.update(phoneNumber)
                    phoneNumber.contact = contact
                }

                try self.context.save()
                print("✅ Updated \(phoneNumbers.count) phone numbers for contact \(contactId)")
            }
        } catch {
            print("❌ Failed to sync contact phone numbers: \(error)")
        }
    }

    // MARK: - Contact Persons Subscriptions

    private func subscribeToContactPersons(farmId: UUID) async {
        let contactIds = await getContactIds(for: farmId)
        guard !contactIds.isEmpty else { return }

        let channel = supabase.client.channel("contact-persons-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "contact_persons"
        )

        await channel.subscribe()
        contactPersonsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleContactPersonChange(change, contactIds: contactIds)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to contact person changes")
    }

    private func handleContactPersonChange(_ change: AnyAction, contactIds: [UUID]) async {
        let record: [String: AnyJSON]
        switch change {
        case .insert(let action): record = action.record
        case .update(let action): record = action.record
        case .delete(let action): record = action.oldRecord
        }

        guard let businessContactIdString = record["business_contact_id"]?.stringValue,
              let businessContactId = UUID(uuidString: businessContactIdString),
              contactIds.contains(businessContactId) else { return }

        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Contact person changed for contact \(businessContactId)")

        // Re-fetch all contact persons for this business and update Core Data
        let repository = ContactRepository(context: context)
        do {
            let persons = try await repository.fetchContactPersons(for: businessContactId)

            try await context.perform { [weak self] in
                guard let self = self else { return }

                // Find the contact
                let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", businessContactId as CVarArg)

                guard let contact = try self.context.fetch(fetchRequest).first else {
                    print("⚠️ Contact not found: \(businessContactId)")
                    return
                }

                // Get existing contact persons
                let existingPersons = (contact.contactPersons as? Set<ContactPerson>) ?? []
                let personIds = Set(persons.map { $0.id })

                // Remove persons that no longer exist
                for person in existingPersons where !personIds.contains(person.id!) {
                    self.context.delete(person)
                }

                // Add or update contact persons
                for dto in persons {
                    let person: ContactPerson
                    if let existing = existingPersons.first(where: { $0.id == dto.id }) {
                        person = existing
                    } else {
                        person = ContactPerson(context: self.context)
                        contact.addToContactPersons(person)
                    }
                    dto.update(person)
                    person.businessContact = contact
                }

                try self.context.save()
                print("✅ Updated \(persons.count) contact persons for contact \(businessContactId)")
            }
        } catch {
            print("❌ Failed to sync contact persons: \(error)")
        }
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

        switch change {
        case .insert(let action):
            print("📥 Realtime: Task inserted")
            await insertTask(from: action.record)

        case .update(let action):
            print("📥 Realtime: Task updated")
            await updateTask(from: action.record)

        case .delete(let action):
            print("📥 Realtime: Task deleted")
            await deleteTask(from: action.oldRecord)
        }
    }

    private func insertTask(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(TaskDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode task DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            // Check if already exists
            let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let existing = try? self.context.fetch(fetchRequest).first {
                print("   ⚠️ Task already exists, updating instead")
                dto.update(existing)

                // Resolve cattle relationship if cattle_id is present
                if let cattleId = dto.cattleId {
                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                    if let cattle = try? self.context.fetch(cattleFetch).first {
                        existing.cattle = cattle
                    }
                }
            } else {
                let task = Task(context: self.context)
                dto.update(task)

                // Resolve cattle relationship if cattle_id is present
                if let cattleId = dto.cattleId {
                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                    if let cattle = try? self.context.fetch(cattleFetch).first {
                        task.cattle = cattle
                    }
                }

                print("   ✅ Inserted task: \(dto.title)")
            }

            try? self.context.save()
        }
    }

    private func updateTask(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(TaskDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode task DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let task = try? self.context.fetch(fetchRequest).first {
                dto.update(task)

                // Resolve cattle relationship if cattle_id is present
                if let cattleId = dto.cattleId {
                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                    if let cattle = try? self.context.fetch(cattleFetch).first {
                        task.cattle = cattle
                    }
                } else {
                    // Clear cattle relationship if no longer associated
                    task.cattle = nil
                }

                print("   ✅ Updated task: \(dto.title)")
            } else {
                print("   ⚠️ Task not found, creating instead")
                let task = Task(context: self.context)
                dto.update(task)

                // Resolve cattle relationship if cattle_id is present
                if let cattleId = dto.cattleId {
                    let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
                    cattleFetch.predicate = NSPredicate(format: "id == %@", cattleId as CVarArg)
                    if let cattle = try? self.context.fetch(cattleFetch).first {
                        task.cattle = cattle
                    }
                }
            }

            try? self.context.save()
        }
    }

    private func deleteTask(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.value as? String,
              let id = UUID(uuidString: idString) else {
            print("   ⚠️ Failed to extract task ID")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let task = try? self.context.fetch(fetchRequest).first {
                self.context.delete(task)
                print("   ✅ Deleted task: \(task.title ?? "unknown")")
                try? self.context.save()
            }
        }
    }

    // MARK: - Pastures Subscriptions

    private func subscribeToPastures(farmId: UUID) async {
        let channel = supabase.client.channel("pastures-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "pastures",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        pasturesChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handlePastureChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to pasture changes")
    }

    private func handlePastureChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        switch change {
        case .insert(let action):
            print("📥 Realtime: Pasture inserted")
            await insertPasture(from: action.record)

        case .update(let action):
            print("📥 Realtime: Pasture updated")
            await updatePasture(from: action.record)

        case .delete(let action):
            print("📥 Realtime: Pasture deleted")
            await deletePasture(from: action.oldRecord)
        }
    }

    private func insertPasture(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(PastureDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode pasture DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            // Check if already exists
            let fetchRequest: NSFetchRequest<Pasture> = Pasture.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let existing = try? self.context.fetch(fetchRequest).first {
                print("   ⚠️ Pasture already exists, updating instead")
                dto.update(existing)
            } else {
                let pasture = Pasture(context: self.context)
                dto.update(pasture)
                print("   ✅ Inserted pasture: \(dto.name)")
            }

            try? self.context.save()
        }
    }

    private func updatePasture(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(PastureDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode pasture DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<Pasture> = Pasture.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let pasture = try? self.context.fetch(fetchRequest).first {
                dto.update(pasture)
                print("   ✅ Updated pasture: \(dto.name)")
            } else {
                print("   ⚠️ Pasture not found, creating instead")
                let pasture = Pasture(context: self.context)
                dto.update(pasture)
            }

            try? self.context.save()
        }
    }

    private func deletePasture(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.value as? String,
              let id = UUID(uuidString: idString) else {
            print("   ⚠️ Failed to extract pasture ID")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<Pasture> = Pasture.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let pasture = try? self.context.fetch(fetchRequest).first {
                self.context.delete(pasture)
                print("   ✅ Deleted pasture: \(pasture.name ?? "unknown")")
                try? self.context.save()
            }
        }
    }

    // MARK: - Pasture Logs Subscriptions

    private func subscribeToPastureLogs(farmId: UUID) async {
        let channel = supabase.client.channel("pasture-logs-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "pasture_logs",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        pastureLogsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handlePastureLogChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to pasture log changes")
    }

    private func handlePastureLogChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        switch change {
        case .insert(let action):
            print("📥 Realtime: Pasture log inserted")
            await insertPastureLog(from: action.record)

        case .update(let action):
            print("📥 Realtime: Pasture log updated")
            await updatePastureLog(from: action.record)

        case .delete(let action):
            print("📥 Realtime: Pasture log deleted")
            await deletePastureLog(from: action.oldRecord)
        }
    }

    private func insertPastureLog(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(PastureLogDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode pasture log DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            // Check if already exists
            let fetchRequest: NSFetchRequest<PastureLog> = PastureLog.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let existing = try? self.context.fetch(fetchRequest).first {
                print("   ⚠️ Pasture log already exists, updating instead")
                dto.update(existing)
            } else {
                let log = PastureLog(context: self.context)
                dto.update(log)

                // Link to pasture
                let pastureFetch: NSFetchRequest<Pasture> = Pasture.fetchRequest()
                pastureFetch.predicate = NSPredicate(format: "id == %@", dto.pastureId as CVarArg)
                if let pasture = try? self.context.fetch(pastureFetch).first {
                    log.pasture = pasture
                }

                print("   ✅ Inserted pasture log: \(dto.title)")
            }

            try? self.context.save()
        }
    }

    private func updatePastureLog(from record: [String: AnyJSON]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: convertAnyJSONToDict(record)),
              let dto = try? JSONDecoder().decode(PastureLogDTO.self, from: jsonData) else {
            print("   ⚠️ Failed to decode pasture log DTO")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<PastureLog> = PastureLog.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let log = try? self.context.fetch(fetchRequest).first {
                dto.update(log)

                // Update pasture link
                let pastureFetch: NSFetchRequest<Pasture> = Pasture.fetchRequest()
                pastureFetch.predicate = NSPredicate(format: "id == %@", dto.pastureId as CVarArg)
                if let pasture = try? self.context.fetch(pastureFetch).first {
                    log.pasture = pasture
                }

                print("   ✅ Updated pasture log: \(dto.title)")
            } else {
                print("   ⚠️ Pasture log not found, creating instead")
                let log = PastureLog(context: self.context)
                dto.update(log)

                // Link to pasture
                let pastureFetch: NSFetchRequest<Pasture> = Pasture.fetchRequest()
                pastureFetch.predicate = NSPredicate(format: "id == %@", dto.pastureId as CVarArg)
                if let pasture = try? self.context.fetch(pastureFetch).first {
                    log.pasture = pasture
                }
            }

            try? self.context.save()
        }
    }

    private func deletePastureLog(from record: [String: AnyJSON]) async {
        guard let idString = record["id"]?.value as? String,
              let id = UUID(uuidString: idString) else {
            print("   ⚠️ Failed to extract pasture log ID")
            return
        }

        await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest: NSFetchRequest<PastureLog> = PastureLog.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let log = try? self.context.fetch(fetchRequest).first {
                self.context.delete(log)
                print("   ✅ Deleted pasture log: \(log.title ?? "unknown")")
                try? self.context.save()
            }
        }
    }

    // MARK: - Documents Subscriptions

    private func subscribeToDocuments(farmId: UUID) async {
        let channel = supabase.client.channel("documents-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "documents",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        documentsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleDocumentChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to document changes")
    }

    private func handleDocumentChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Document changed")
        // TODO: Implement document sync using DocumentDTO when repository is ready
    }

    // MARK: - Cattle Stages Subscriptions

    private func subscribeToCattleStages(farmId: UUID) async {
        let channel = supabase.client.channel("cattle-stages-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "cattle_stages",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        cattleStagesChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleCattleStageChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to cattle stage changes")
    }

    private func handleCattleStageChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Cattle stage changed")
        // TODO: Implement cattle stage sync using CattleStageDTO when repository is ready
    }

    // MARK: - Health Conditions Subscriptions

    private func subscribeToHealthConditions(farmId: UUID) async {
        let channel = supabase.client.channel("health-conditions-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "health_conditions",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        healthConditionsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleHealthConditionChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to health condition changes")
    }

    private func handleHealthConditionChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Health condition changed")
        // TODO: Implement health condition sync using HealthConditionDTO when repository is ready
    }

    // MARK: - Health Record Types Subscriptions

    private func subscribeToHealthRecordTypes(farmId: UUID) async {
        let channel = supabase.client.channel("health-record-types-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "health_record_types",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        healthRecordTypesChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleHealthRecordTypeChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to health record type changes")
    }

    private func handleHealthRecordTypeChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Health record type changed")
        // TODO: Implement health record type sync using HealthRecordTypeDTO when repository is ready
    }

    // MARK: - Processors Subscriptions

    private func subscribeToProcessors(farmId: UUID) async {
        let channel = supabase.client.channel("processors-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "processors",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        processorsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleProcessorChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to processor changes")
    }

    private func handleProcessorChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Processor changed")
        // TODO: Implement processor sync using ProcessorDTO when repository is ready
    }

    // MARK: - Veterinarians Subscriptions

    private func subscribeToVeterinarians(farmId: UUID) async {
        let channel = supabase.client.channel("veterinarians-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "veterinarians",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        veterinariansChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleVeterinarianChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to veterinarian changes")
    }

    private func handleVeterinarianChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Veterinarian changed")
        // TODO: Implement veterinarian sync using VeterinarianDTO when repository is ready
    }

    // MARK: - Production Paths Subscriptions

    private func subscribeToProductionPaths(farmId: UUID) async {
        let channel = supabase.client.channel("production-paths-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "production_paths",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        productionPathsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleProductionPathChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to production path changes")
    }

    private func handleProductionPathChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Production path changed")
        // TODO: Implement production path sync using ProductionPathDTO when repository is ready
    }

    // MARK: - Production Path Stages Subscriptions

    private func subscribeToProductionPathStages(farmId: UUID) async {
        let channel = supabase.client.channel("production-path-stages-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "production_path_stages",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        productionPathStagesChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleProductionPathStageChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to production path stage changes")
    }

    private func handleProductionPathStageChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Production path stage changed")
        // TODO: Implement production path stage sync using ProductionPathStageDTO when repository is ready
    }

    // MARK: - Treatment Plans Subscriptions

    private func subscribeToTreatmentPlans(farmId: UUID) async {
        let channel = supabase.client.channel("treatment-plans-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "treatment_plans",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        treatmentPlansChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleTreatmentPlanChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to treatment plan changes")
    }

    private func handleTreatmentPlanChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Treatment plan changed")
        // TODO: Implement treatment plan sync using TreatmentPlanDTO when repository is ready
    }

    // MARK: - Treatment Plan Steps Subscriptions

    private func subscribeToTreatmentPlanSteps(farmId: UUID) async {
        let channel = supabase.client.channel("treatment-plan-steps-\(farmId)")
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "treatment_plan_steps",
            filter: "farm_id=eq.\(farmId.uuidString)"
        )

        await channel.subscribe()
        treatmentPlanStepsChannel = channel

        let task = _Concurrency.Task {
            for try await change in changeStream {
                await handleTreatmentPlanStepChange(change)
            }
        }
        subscriptionTasks.append(task)
        print("✅ Subscribed to treatment plan step changes")
    }

    private func handleTreatmentPlanStepChange(_ change: AnyAction) async {
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        print("📥 Realtime: Treatment plan step changed")
        // TODO: Implement treatment plan step sync using TreatmentPlanStepDTO when repository is ready
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

    private func getContactIds(for farmId: UUID) async -> [UUID] {
        await context.perform { [weak self] in
            guard let self = self else { return [] }

            let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)
            fetchRequest.propertiesToFetch = ["id"]

            guard let contacts = try? self.context.fetch(fetchRequest) else {
                return []
            }

            return contacts.compactMap { $0.id }
        }
    }

    /// Convert AnyJSON dictionary to regular Swift dictionary for JSONSerialization
    private func convertAnyJSONToDict(_ anyJSON: [String: AnyJSON]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in anyJSON {
            result[key] = value.value
        }
        return result
    }
}
