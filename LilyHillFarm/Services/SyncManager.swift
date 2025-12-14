//
//  SyncManager.swift
//  LilyHillFarm
//
//  Central sync manager coordinating all data synchronization
//

import Foundation
internal import CoreData
import Combine

@MainActor
class SyncManager: ObservableObject {
    // MARK: - Published Properties

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var syncProgress: Double = 0.0

    // MARK: - Repositories

    private let breedRepository: BreedRepository
    private let treatmentPlanRepository: TreatmentPlanRepository
    private let treatmentPlanStepRepository: TreatmentPlanStepRepository
    private let contactRepository: ContactRepository

    // Dynamic lookup repositories
    private let cattleStageRepository: CattleStageRepository
    private let productionPathRepository: ProductionPathRepository
    private let healthRecordTypeRepository: HealthRecordTypeRepository
    private let medicationRepository: MedicationRepository
    private let veterinarianRepository: VeterinarianRepository
    private let processorRepository: ProcessorRepository
    private let buyerRepository: BuyerRepository
    private let pastureRepository: PastureRepository

    private let cattleRepository: CattleRepository
    private let healthRecordRepository: HealthRecordRepository
    private let pregnancyRecordRepository: PregnancyRecordRepository
    private let calvingRecordRepository: CalvingRecordRepository
    private let saleRecordRepository: SaleRecordRepository
    private let processingRecordRepository: ProcessingRecordRepository
    private let mortalityRecordRepository: MortalityRecordRepository
    private let stageTransitionRepository: StageTransitionRepository
    private let photoRepository: PhotoRepository
    private let taskRepository: TaskRepository
    private let pastureLogRepository: PastureLogRepository
    private let context: NSManagedObjectContext

    // MARK: - Initialization

    init(context: NSManagedObjectContext) {
        self.context = context
        self.breedRepository = BreedRepository(context: context)
        self.treatmentPlanRepository = TreatmentPlanRepository(context: context)
        self.treatmentPlanStepRepository = TreatmentPlanStepRepository(context: context)
        self.contactRepository = ContactRepository(context: context)

        // Initialize dynamic lookup repositories
        self.cattleStageRepository = CattleStageRepository(context: context)
        self.productionPathRepository = ProductionPathRepository(context: context)
        self.healthRecordTypeRepository = HealthRecordTypeRepository(context: context)
        self.medicationRepository = MedicationRepository(context: context)
        self.veterinarianRepository = VeterinarianRepository(context: context)
        self.processorRepository = ProcessorRepository(context: context)
        self.buyerRepository = BuyerRepository(context: context)
        self.pastureRepository = PastureRepository(context: context)

        self.cattleRepository = CattleRepository(context: context)
        self.healthRecordRepository = HealthRecordRepository(context: context)
        self.pregnancyRecordRepository = PregnancyRecordRepository(context: context)
        self.calvingRecordRepository = CalvingRecordRepository(context: context)
        self.saleRecordRepository = SaleRecordRepository(context: context)
        self.processingRecordRepository = ProcessingRecordRepository(context: context)
        self.mortalityRecordRepository = MortalityRecordRepository(context: context)
        self.stageTransitionRepository = StageTransitionRepository(context: context)
        self.photoRepository = PhotoRepository(context: context)
        self.taskRepository = TaskRepository(context: context)
        self.pastureLogRepository = PastureLogRepository(context: context)
    }

    // MARK: - Full Sync

    /// Perform full sync of all data
    func performFullSync() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }

        isSyncing = true
        syncStatus = .syncing
        syncProgress = 0.0

        // Disable auto-sync during pull to avoid pushing everything back
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        var syncErrors: [String: Error] = [:]

        // 1. Sync reference data first (10%)
        print("📊 Syncing breeds...")
        do {
            try await breedRepository.syncFromSupabase()
        } catch {
            print("❌ Breeds sync failed: \(error)")
            syncErrors["breeds"] = error
        }
        syncProgress = 0.05

        print("📊 Syncing treatment plans...")
        do {
            try await treatmentPlanRepository.syncFromSupabase()
        } catch {
            print("❌ Treatment plans sync failed: \(error)")
            syncErrors["treatment_plans"] = error
        }
        syncProgress = 0.08

        print("📊 Syncing treatment plan steps...")
        do {
            try await treatmentPlanStepRepository.syncFromSupabase()
        } catch {
            print("❌ Treatment plan steps sync failed: \(error)")
            syncErrors["treatment_plan_steps"] = error
        }
        syncProgress = 0.08

        print("📊 Syncing contacts...")
        do {
            try await contactRepository.syncFromSupabase()
        } catch {
            print("❌ Contacts sync failed: \(error)")
            syncErrors["contacts"] = error
        }
        syncProgress = 0.10

        // Sync dynamic lookup tables (10-20%)
        print("📊 Syncing cattle stages...")
        do {
            try await cattleStageRepository.syncFromSupabase()
        } catch {
            print("❌ Cattle stages sync failed: \(error)")
            syncErrors["cattle_stages"] = error
        }
        syncProgress = 0.11

        print("📊 Syncing production paths...")
        do {
            try await productionPathRepository.syncFromSupabase()
        } catch {
            print("❌ Production paths sync failed: \(error)")
            syncErrors["production_paths"] = error
        }
        syncProgress = 0.12

        print("📊 Syncing health record types...")
        do {
            try await healthRecordTypeRepository.syncFromSupabase()
        } catch {
            print("❌ Health record types sync failed: \(error)")
            syncErrors["health_record_types"] = error
        }
        syncProgress = 0.14

        print("📊 Syncing medications...")
        do {
            try await medicationRepository.syncFromSupabase()
        } catch {
            print("❌ Medications sync failed: \(error)")
            syncErrors["medications"] = error
        }
        syncProgress = 0.15

        print("📊 Syncing veterinarians...")
        do {
            try await veterinarianRepository.syncFromSupabase()
        } catch {
            print("❌ Veterinarians sync failed: \(error)")
            syncErrors["veterinarians"] = error
        }
        syncProgress = 0.16

        print("📊 Syncing processors...")
        do {
            try await processorRepository.syncFromSupabase()
        } catch {
            print("❌ Processors sync failed: \(error)")
            syncErrors["processors"] = error
        }
        syncProgress = 0.17

        print("📊 Syncing buyers...")
        do {
            try await buyerRepository.syncFromSupabase()
        } catch {
            print("❌ Buyers sync failed: \(error)")
            syncErrors["buyers"] = error
        }
        syncProgress = 0.18

        print("📊 Syncing pastures...")
        do {
            try await pastureRepository.syncFromSupabase()
        } catch {
            print("❌ Pastures sync failed: \(error)")
            syncErrors["pastures"] = error
        }
        syncProgress = 0.20

        // 2. Sync cattle (30%) - must happen before related records
        print("📊 Syncing cattle...")
        do {
            try await cattleRepository.syncFromSupabase()
        } catch {
            print("❌ Cattle sync failed: \(error)")
            syncErrors["cattle"] = error
        }
        syncProgress = 0.30

        // 3. Sync health records (50%)
        print("📊 Syncing health records...")
        do {
            try await healthRecordRepository.syncFromSupabase()
        } catch {
            print("❌ Health records sync failed: \(error)")
            syncErrors["health_records"] = error
        }
        syncProgress = 0.50

        // 4. Sync pregnancy records (60%)
        print("📊 Syncing pregnancy records...")
        do {
            try await pregnancyRecordRepository.syncFromSupabase()
        } catch {
            print("❌ Pregnancy records sync failed: \(error)")
            syncErrors["pregnancy_records"] = error
        }
        syncProgress = 0.60

        // 5. Sync calving records (65%)
        print("📊 Syncing calving records...")
        do {
            try await calvingRecordRepository.syncFromSupabase()
        } catch {
            print("❌ Calving records sync failed: \(error)")
            syncErrors["calving_records"] = error
        }
        syncProgress = 0.65

        // 6. Sync sale records (70%)
        print("📊 Syncing sale records...")
        do {
            try await saleRecordRepository.syncFromSupabase()
        } catch {
            print("❌ Sale records sync failed: \(error)")
            syncErrors["sale_records"] = error
        }
        syncProgress = 0.70

        // 7. Sync processing records (75%)
        print("📊 Syncing processing records...")
        do {
            try await processingRecordRepository.syncFromSupabase()
        } catch {
            print("❌ Processing records sync failed: \(error)")
            syncErrors["processing_records"] = error
        }
        syncProgress = 0.75

        // 8. Sync mortality records (80%)
        print("📊 Syncing mortality records...")
        do {
            try await mortalityRecordRepository.syncFromSupabase()
        } catch {
            print("❌ Mortality records sync failed: \(error)")
            syncErrors["mortality_records"] = error
        }
        syncProgress = 0.80

        // 9. Sync stage transitions (85%)
        print("📊 Syncing stage transitions...")
        do {
            try await stageTransitionRepository.syncFromSupabase()
        } catch {
            print("❌ Stage transitions sync failed: \(error)")
            syncErrors["stage_transitions"] = error
        }
        syncProgress = 0.85

        // 10. Sync photos (90%)
        print("📊 Syncing photos...")
        do {
            try await photoRepository.syncFromSupabase()
        } catch {
            print("❌ Photos sync failed: \(error)")
            syncErrors["photos"] = error
        }
        syncProgress = 0.90

        // 11. Sync tasks (93%)
        print("📊 Syncing tasks...")
        do {
            try await taskRepository.syncFromSupabase()
        } catch {
            print("❌ Tasks sync failed: \(error)")
            syncErrors["tasks"] = error
        }
        syncProgress = 0.93

        // 12. Sync pasture logs (96%)
        print("📊 Syncing pasture logs...")
        do {
            try await pastureLogRepository.syncFromSupabase()
        } catch {
            print("❌ Pasture logs sync failed: \(error)")
            syncErrors["pasture_logs"] = error
        }
        syncProgress = 0.96

        // Complete (100%)
        syncProgress = 1.0
        lastSyncDate = Date()

        // Report sync status
        if syncErrors.isEmpty {
            syncStatus = .success
            print("✅ Full sync completed successfully")
        } else {
            syncStatus = .success  // Partial success - some synced
            print("⚠️ Sync completed with \(syncErrors.count) errors:")
            for (table, error) in syncErrors {
                print("   - \(table): \(error.localizedDescription)")
            }
        }

        // Debug: Print counts
        await printSyncSummary()

        isSyncing = false
    }

    private func printSyncSummary() async {
        await context.perform {
            let breedFetch: NSFetchRequest<Breed> = Breed.fetchRequest()
            let breedCount = (try? self.context.count(for: breedFetch)) ?? 0

            let treatmentPlanFetch: NSFetchRequest<TreatmentPlan> = TreatmentPlan.fetchRequest()
            let treatmentPlanCount = (try? self.context.count(for: treatmentPlanFetch)) ?? 0

            let treatmentStepFetch: NSFetchRequest<TreatmentPlanStep> = TreatmentPlanStep.fetchRequest()
            let treatmentStepCount = (try? self.context.count(for: treatmentStepFetch)) ?? 0

            let contactFetch: NSFetchRequest<Contact> = Contact.fetchRequest()
            let contactCount = (try? self.context.count(for: contactFetch)) ?? 0

            let cattleFetch: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            let cattleCount = (try? self.context.count(for: cattleFetch)) ?? 0

            let healthFetch: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
            let healthCount = (try? self.context.count(for: healthFetch)) ?? 0

            let pregnancyFetch: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
            let pregnancyCount = (try? self.context.count(for: pregnancyFetch)) ?? 0

            let calvingFetch: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
            let calvingCount = (try? self.context.count(for: calvingFetch)) ?? 0

            let saleFetch: NSFetchRequest<SaleRecord> = SaleRecord.fetchRequest()
            let saleCount = (try? self.context.count(for: saleFetch)) ?? 0

            let processingFetch: NSFetchRequest<ProcessingRecord> = ProcessingRecord.fetchRequest()
            let processingCount = (try? self.context.count(for: processingFetch)) ?? 0

            let mortalityFetch: NSFetchRequest<MortalityRecord> = MortalityRecord.fetchRequest()
            let mortalityCount = (try? self.context.count(for: mortalityFetch)) ?? 0

            let stageTransitionFetch: NSFetchRequest<StageTransition> = StageTransition.fetchRequest()
            let stageTransitionCount = (try? self.context.count(for: stageTransitionFetch)) ?? 0

            let photoFetch: NSFetchRequest<Photo> = Photo.fetchRequest()
            let photoCount = (try? self.context.count(for: photoFetch)) ?? 0

            let taskFetch: NSFetchRequest<Task> = Task.fetchRequest()
            let taskCount = (try? self.context.count(for: taskFetch)) ?? 0

            let pastureLogFetch: NSFetchRequest<PastureLog> = PastureLog.fetchRequest()
            let pastureLogCount = (try? self.context.count(for: pastureLogFetch)) ?? 0

            print("📊 Sync Summary:")
            print("   - Breeds: \(breedCount)")
            print("   - Treatment Plans: \(treatmentPlanCount)")
            print("   - Treatment Steps: \(treatmentStepCount)")
            print("   - Contacts: \(contactCount)")
            print("   - Cattle: \(cattleCount)")
            print("   - Health Records: \(healthCount)")
            print("   - Pregnancy Records: \(pregnancyCount)")
            print("   - Calving Records: \(calvingCount)")
            print("   - Sale Records: \(saleCount)")
            print("   - Processing Records: \(processingCount)")
            print("   - Mortality Records: \(mortalityCount)")
            print("   - Stage Transitions: \(stageTransitionCount)")
            print("   - Photos: \(photoCount)")
            print("   - Tasks: \(taskCount)")
            print("   - Pasture Logs: \(pastureLogCount)")
        }
    }

    // MARK: - Entity-Specific Sync

    /// Sync only cattle
    func syncCattle() async throws {
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Disable auto-sync during pull
        AutoSyncService.isEnabled = false
        defer { AutoSyncService.isEnabled = true }

        try await cattleRepository.syncFromSupabase()
        lastSyncDate = Date()
    }

    // MARK: - Push Changes

    /// Push a specific cattle to Supabase
    func pushCattle(_ cattle: Cattle) async throws {
        try await cattleRepository.pushToSupabase(cattle)
    }

    // MARK: - Background Sync

    /// Start automatic background sync
    func startBackgroundSync(interval: TimeInterval = 300) {
        // Sync every 5 minutes (300 seconds)
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            _Concurrency.Task { @MainActor in
                await self?.performFullSync()
            }
        }
    }

    // MARK: - Manual Triggers

    /// Pull latest data from server
    func pullFromServer() async {
        // performFullSync already disables AutoSync
        await performFullSync()
    }

    /// Push all pending local records to server
    func pushAllPendingRecords() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }

        isSyncing = true
        syncStatus = .syncing
        syncProgress = 0.0
        defer {
            isSyncing = false
        }

        do {
            print("📤 Starting push of all local records to Supabase...")

            // Push in order to avoid foreign key constraint violations
            // Cattle must be pushed first since other entities reference them

            // 1. Push cattle (20%)
            print("📤 Pushing cattle...")
            try await pushAllCattle()
            syncProgress = 0.20

            // 2. Push health records (30%)
            print("📤 Pushing health records...")
            try await pushAllHealthRecords()
            syncProgress = 0.30

            // 3. Push pregnancy records (40%)
            print("📤 Pushing pregnancy records...")
            try await pushAllPregnancyRecords()
            syncProgress = 0.40

            // 4. Push calving records (50%)
            print("📤 Pushing calving records...")
            try await pushAllCalvingRecords()
            syncProgress = 0.50

            // 5. Push sale records (60%)
            print("📤 Pushing sale records...")
            try await pushAllSaleRecords()
            syncProgress = 0.60

            // 6. Push processing records (70%)
            print("📤 Pushing processing records...")
            try await pushAllProcessingRecords()
            syncProgress = 0.70

            // 7. Push mortality records (80%)
            print("📤 Pushing mortality records...")
            try await pushAllMortalityRecords()
            syncProgress = 0.80

            // 8. Push stage transitions (90%)
            print("📤 Pushing stage transitions...")
            try await pushAllStageTransitions()
            syncProgress = 0.90

            // 9. Push photos (95%)
            print("📤 Pushing photos...")
            try await pushAllPhotos()
            syncProgress = 0.95

            // 10. Push tasks (100%)
            print("📤 Pushing tasks...")
            try await pushAllTasks()
            syncProgress = 1.0

            syncStatus = .success
            print("✅ Successfully pushed all local records to Supabase")

        } catch {
            print("❌ Push failed: \(error)")
            syncStatus = .failed(error)
        }
    }

    /// Push pending local changes to server
    func pushToServer() async {
        await pushAllPendingRecords()
    }

    // MARK: - Push Individual Entity Types

    private func pushAllCattle() async throws {
        let cattle = try await context.perform {
            let request: NSFetchRequest<Cattle> = Cattle.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(cattle.count) cattle to push")
        for animal in cattle {
            do {
                try await cattleRepository.pushToSupabase(animal)
            } catch {
                print("   ⚠️ Failed to push cattle \(animal.tagNumber ?? "unknown"): \(error)")
            }
        }
    }

    private func pushAllHealthRecords() async throws {
        let records = try await context.perform {
            let request: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(records.count) health records to push")
        for record in records {
            do {
                try await healthRecordRepository.pushToSupabase(record)
            } catch {
                print("   ⚠️ Failed to push health record: \(error)")
            }
        }
    }

    private func pushAllPregnancyRecords() async throws {
        let records = try await context.perform {
            let request: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(records.count) pregnancy records to push")
        for record in records {
            do {
                try await pregnancyRecordRepository.pushToSupabase(record)
            } catch {
                print("   ⚠️ Failed to push pregnancy record: \(error)")
            }
        }
    }

    private func pushAllCalvingRecords() async throws {
        let records = try await context.perform {
            let request: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(records.count) calving records to push")
        for record in records {
            do {
                try await calvingRecordRepository.pushToSupabase(record)
            } catch {
                print("   ⚠️ Failed to push calving record: \(error)")
            }
        }
    }

    private func pushAllSaleRecords() async throws {
        let records = try await context.perform {
            let request: NSFetchRequest<SaleRecord> = SaleRecord.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(records.count) sale records to push")
        for record in records {
            do {
                try await saleRecordRepository.pushToSupabase(record)
            } catch {
                print("   ⚠️ Failed to push sale record: \(error)")
            }
        }
    }

    private func pushAllProcessingRecords() async throws {
        let records = try await context.perform {
            let request: NSFetchRequest<ProcessingRecord> = ProcessingRecord.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(records.count) processing records to push")
        for record in records {
            do {
                try await processingRecordRepository.pushToSupabase(record)
            } catch {
                print("   ⚠️ Failed to push processing record: \(error)")
            }
        }
    }

    private func pushAllMortalityRecords() async throws {
        let records = try await context.perform {
            let request: NSFetchRequest<MortalityRecord> = MortalityRecord.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(records.count) mortality records to push")
        for record in records {
            do {
                try await mortalityRecordRepository.pushToSupabase(record)
            } catch {
                print("   ⚠️ Failed to push mortality record: \(error)")
            }
        }
    }

    private func pushAllStageTransitions() async throws {
        let records = try await context.perform {
            let request: NSFetchRequest<StageTransition> = StageTransition.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(records.count) stage transitions to push")
        for record in records {
            do {
                try await stageTransitionRepository.pushToSupabase(record)
            } catch {
                print("   ⚠️ Failed to push stage transition: \(error)")
            }
        }
    }

    private func pushAllPhotos() async throws {
        let photos = try await context.perform {
            let request: NSFetchRequest<Photo> = Photo.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(photos.count) photos to push")
        for photo in photos {
            do {
                try await photoRepository.pushToSupabase(photo)
            } catch {
                print("   ⚠️ Failed to push photo: \(error)")
            }
        }
    }

    private func pushAllTasks() async throws {
        let tasks = try await context.perform {
            let request: NSFetchRequest<Task> = Task.fetchRequest()
            return try self.context.fetch(request)
        }

        print("   Found \(tasks.count) tasks to push")
        for task in tasks {
            do {
                try await taskRepository.pushToSupabase(task)
            } catch {
                print("   ⚠️ Failed to push task: \(error)")
            }
        }
    }
}

// MARK: - Convenience Extensions

extension SyncManager {
    /// Format last sync date for display
    var lastSyncDateFormatted: String {
        guard let date = lastSyncDate else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Check if sync is overdue (more than 1 hour since last sync)
    var isSyncOverdue: Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > 3600 // 1 hour
    }
}
