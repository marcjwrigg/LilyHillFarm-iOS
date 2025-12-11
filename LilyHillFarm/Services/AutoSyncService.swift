//
//  AutoSyncService.swift
//  LilyHillFarm
//
//  Automatic bidirectional sync service
//  Listens for Core Data changes and pushes them to Supabase
//

import Foundation
internal import CoreData
import Combine
import Supabase

@MainActor
class AutoSyncService: ObservableObject {
    private let context: NSManagedObjectContext
    private let contactRepository: ContactRepository
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

    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false

    // Flag to temporarily disable auto-sync (e.g., during pull operations)
    static var isEnabled = true

    @Published var lastPushDate: Date?
    @Published var pendingChanges: Int = 0

    init(context: NSManagedObjectContext) {
        self.context = context
        self.contactRepository = ContactRepository(context: context)
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

        setupNotifications()
    }

    private func setupNotifications() {
        // Listen for Core Data save notifications
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .sink { [weak self] notification in
                guard let self = self else { return }
                _Concurrency.Task { @MainActor in
                    await self.handleContextSave(notification)
                }
            }
            .store(in: &cancellables)
    }

    private func handleContextSave(_ notification: Notification) async {
        guard AutoSyncService.isEnabled else {
            // Auto-sync is disabled (e.g., during pull from server)
            return
        }

        guard !isSyncing else {
            print("⏭️ AutoSync: Already syncing, skipping...")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let userInfo = notification.userInfo

        // Handle inserted objects
        if let insertedObjects = userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            await pushInsertedObjects(insertedObjects)
        }

        // Handle updated objects
        if let updatedObjects = userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            await pushUpdatedObjects(updatedObjects)
        }

        // Handle deleted objects
        if let deletedObjects = userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            await pushDeletedObjects(deletedObjects)
        }

        lastPushDate = Date()
    }

    private func pushInsertedObjects(_ objects: Set<NSManagedObject>) async {
        print("🔍 AutoSync: Processing \(objects.count) inserted objects")

        // Sort objects to ensure proper insertion order (parent entities before children)
        // This prevents foreign key constraint violations
        let sortedObjects = objects.sorted { obj1, obj2 in
            let priority1 = insertionPriority(for: obj1)
            let priority2 = insertionPriority(for: obj2)
            return priority1 < priority2
        }

        for object in sortedObjects {
            print("🔍 AutoSync: Processing object type: \(type(of: object))")

            do {
                switch object {
                case let contact as Contact:
                    print("📤 AutoSync: Pushing new contact \(contact.name ?? "unknown")")
                    _ = try await contactRepository.create(contact)

                case let cattle as Cattle:
                    print("📤 AutoSync: Pushing new cattle \(cattle.tagNumber ?? "unknown")")
                    _ = try await cattleRepository.create(cattle)

                case let healthRecord as HealthRecord:
                    print("📤 AutoSync: Pushing new health record")
                    _ = try await healthRecordRepository.create(healthRecord)

                case let pregnancy as PregnancyRecord:
                    print("📤 AutoSync: Pushing new pregnancy record")
                    _ = try await pregnancyRecordRepository.create(pregnancy)

                case let calvingRecord as CalvingRecord:
                    print("📤 AutoSync: Pushing new calving record")
                    _ = try await calvingRecordRepository.create(calvingRecord)

                case let saleRecord as SaleRecord:
                    print("📤 AutoSync: Pushing new sale record")
                    _ = try await saleRecordRepository.create(saleRecord)

                case let processingRecord as ProcessingRecord:
                    print("📤 AutoSync: Pushing new processing record")
                    _ = try await processingRecordRepository.create(processingRecord)

                case let mortalityRecord as MortalityRecord:
                    print("📤 AutoSync: Pushing new mortality record")
                    _ = try await mortalityRecordRepository.create(mortalityRecord)

                case let stageTransition as StageTransition:
                    print("📤 AutoSync: Pushing new stage transition")
                    _ = try await stageTransitionRepository.create(stageTransition)

                case let photo as Photo:
                    print("📤 AutoSync: Pushing new photo")
                    try await photoRepository.pushToSupabase(photo)

                case let task as Task:
                    print("📤 AutoSync: Pushing new task \(task.title ?? "untitled")")
                    try await taskRepository.pushToSupabase(task)

                default:
                    break
                }
            } catch let error as PostgrestError {
                // Handle foreign key constraint errors by deleting the invalid record
                if error.code == "23503" {
                    print("⚠️ AutoSync: Deleting \(type(of: object)) due to missing relationship (foreign key constraint)")
                    print("   Error details: \(error.message ?? "no message")")
                    if let hint = error.hint {
                        print("   Hint: \(hint)")
                    }

                    // Delete the invalid object from Core Data
                    context.delete(object)
                    do {
                        try context.save()
                        print("   🗑️ Deleted invalid \(type(of: object)) from Core Data")
                    } catch {
                        print("   ❌ Failed to delete invalid object: \(error)")
                    }
                } else {
                    print("❌ AutoSync: Failed to push \(type(of: object)): \(error)")
                }
            } catch {
                print("❌ AutoSync: Failed to push \(type(of: object)): \(error)")
            }
        }
    }

    private func pushUpdatedObjects(_ objects: Set<NSManagedObject>) async {
        for object in objects {
            do {
                switch object {
                case let contact as Contact:
                    print("📤 AutoSync: Pushing updated contact \(contact.name ?? "unknown")")
                    _ = try await contactRepository.update(contact)

                case let cattle as Cattle:
                    print("📤 AutoSync: Pushing updated cattle \(cattle.tagNumber ?? "unknown")")
                    _ = try await cattleRepository.update(cattle)

                case let healthRecord as HealthRecord:
                    print("📤 AutoSync: Pushing updated health record")
                    _ = try await healthRecordRepository.update(healthRecord)

                case let pregnancy as PregnancyRecord:
                    print("📤 AutoSync: Pushing updated pregnancy record")
                    _ = try await pregnancyRecordRepository.update(pregnancy)

                case let calvingRecord as CalvingRecord:
                    print("📤 AutoSync: Pushing updated calving record")
                    _ = try await calvingRecordRepository.update(calvingRecord)

                case let saleRecord as SaleRecord:
                    print("📤 AutoSync: Pushing updated sale record")
                    _ = try await saleRecordRepository.update(saleRecord)

                case let processingRecord as ProcessingRecord:
                    print("📤 AutoSync: Pushing updated processing record")
                    _ = try await processingRecordRepository.update(processingRecord)

                case let mortalityRecord as MortalityRecord:
                    print("📤 AutoSync: Pushing updated mortality record")
                    _ = try await mortalityRecordRepository.update(mortalityRecord)

                case let stageTransition as StageTransition:
                    print("📤 AutoSync: Pushing updated stage transition")
                    _ = try await stageTransitionRepository.update(stageTransition)

                case let photo as Photo:
                    print("📤 AutoSync: Pushing updated photo")
                    try await photoRepository.pushToSupabase(photo)

                case let task as Task:
                    print("📤 AutoSync: Pushing updated task \(task.title ?? "untitled")")
                    try await taskRepository.pushToSupabase(task)

                default:
                    break
                }
            } catch let error as PostgrestError {
                // Handle foreign key constraint errors gracefully
                if error.code == "23503" {
                    print("⚠️ AutoSync: Skipping \(type(of: object)) due to missing relationship (foreign key constraint)")
                } else {
                    print("❌ AutoSync: Failed to update \(type(of: object)): \(error)")
                }
            } catch {
                print("❌ AutoSync: Failed to update \(type(of: object)): \(error)")
            }
        }
    }

    private func pushDeletedObjects(_ objects: Set<NSManagedObject>) async {
        for object in objects {
            do {
                switch object {
                case let contact as Contact:
                    if let id = contact.id {
                        print("📤 AutoSync: Pushing deleted contact \(contact.name ?? "unknown")")
                        try await contactRepository.delete(id)
                    }

                case let cattle as Cattle:
                    if let id = cattle.id {
                        print("📤 AutoSync: Pushing deleted cattle \(cattle.tagNumber ?? "unknown")")
                        try await cattleRepository.delete(id)
                    }

                case let healthRecord as HealthRecord:
                    if let id = healthRecord.id {
                        print("📤 AutoSync: Pushing deleted health record")
                        try await healthRecordRepository.delete(id)
                    }

                case let pregnancy as PregnancyRecord:
                    if let id = pregnancy.id {
                        print("📤 AutoSync: Pushing deleted pregnancy record")
                        try await pregnancyRecordRepository.delete(id)
                    }

                case let calvingRecord as CalvingRecord:
                    if let id = calvingRecord.id {
                        print("📤 AutoSync: Pushing deleted calving record")
                        try await calvingRecordRepository.delete(id)
                    }

                case let saleRecord as SaleRecord:
                    if let id = saleRecord.id {
                        print("📤 AutoSync: Pushing deleted sale record")
                        try await saleRecordRepository.delete(id)
                    }

                case let processingRecord as ProcessingRecord:
                    if let id = processingRecord.id {
                        print("📤 AutoSync: Pushing deleted processing record")
                        try await processingRecordRepository.delete(id)
                    }

                case let mortalityRecord as MortalityRecord:
                    if let id = mortalityRecord.id {
                        print("📤 AutoSync: Pushing deleted mortality record")
                        try await mortalityRecordRepository.delete(id)
                    }

                case let stageTransition as StageTransition:
                    if let id = stageTransition.id {
                        print("📤 AutoSync: Pushing deleted stage transition")
                        try await stageTransitionRepository.delete(id)
                    }

                case let photo as Photo:
                    if let id = photo.id {
                        print("📤 AutoSync: Pushing deleted photo")
                        try await photoRepository.delete(id)
                    }

                case let task as Task:
                    if let id = task.id {
                        print("📤 AutoSync: Pushing deleted task \(task.title ?? "untitled")")
                        try await taskRepository.delete(id)
                    }

                default:
                    break
                }
            } catch {
                print("❌ AutoSync: Failed to delete \(type(of: object)): \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    /// Determines insertion priority to avoid foreign key constraint violations
    /// Lower numbers are inserted first
    private func insertionPriority(for object: NSManagedObject) -> Int {
        switch object {
        case is Contact:
            return 0 // Insert contacts first (cattle and other entities may reference them)
        case is Cattle:
            return 1 // Insert cattle second (other entities reference them)
        case is HealthRecord:
            return 2 // Insert health records before tasks (tasks reference them)
        case is PregnancyRecord:
            return 2 // Insert pregnancy records at same level as health records
        case is CalvingRecord:
            return 2 // Insert calving records at same level as health/pregnancy records
        case is SaleRecord:
            return 2 // Insert sale records at same level as other records
        case is ProcessingRecord:
            return 2 // Insert processing records at same level as other records
        case is MortalityRecord:
            return 2 // Insert mortality records at same level as other records
        case is StageTransition:
            return 2 // Insert stage transitions at same level as other records
        case is Photo:
            return 3 // Photos can reference health records or cattle
        case is Task:
            return 4 // Tasks reference health records and cattle - insert last
        default:
            return 5 // Unknown entities last
        }
    }
}
