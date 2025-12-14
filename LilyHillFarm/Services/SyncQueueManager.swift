//
//  SyncQueueManager.swift
//  LilyHillFarm
//
//  Manages sync queue and retry logic
//

import Foundation
internal import CoreData
import Combine

@MainActor
class SyncQueueManager: ObservableObject {
    // MARK: - Singleton

    static let shared = SyncQueueManager()

    // MARK: - Properties

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var failedCount: Int = 0
    @Published private(set) var isProcessing: Bool = false

    private let queue: SyncQueue
    private let networkMonitor: NetworkMonitor
    private var networkCancellable: AnyCancellable?
    private var isRetrying = false

    // Repositories
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

    // MARK: - Initialization

    private init() {
        self.queue = SyncQueue()
        self.networkMonitor = NetworkMonitor.shared
        self.context = PersistenceController.shared.container.viewContext

        // Initialize repositories
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

        updateCounts()
        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        // Check current network state immediately
        if networkMonitor.isConnected && pendingCount > 0 {
            print("📶 SyncQueueManager: Network already available, processing queue...")
            _Concurrency.Task { @MainActor in
                await self.processQueue()
            }
        }

        // Retry queue when network becomes available
        networkCancellable = networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self else { return }

                if isConnected && self.pendingCount > 0 {
                    print("📶 SyncQueueManager: Network available, processing queue...")
                    _Concurrency.Task { @MainActor in
                        await self.processQueue()
                    }
                }
            }
    }

    // MARK: - Queue Management

    /// Add operation to sync queue
    func enqueue(_ operation: SyncOperation) {
        queue.enqueue(operation)
        updateCounts()
    }

    /// Process all pending operations in queue
    func processQueue() async {
        guard !isProcessing else {
            print("⏭️ SyncQueueManager: Already processing queue")
            return
        }

        guard networkMonitor.isSuitableForSync else {
            print("📵 SyncQueueManager: No network connection, skipping queue processing")
            return
        }

        isProcessing = true
        defer {
            isProcessing = false
            updateCounts()
        }

        let pending = queue.pendingOperations()
        guard !pending.isEmpty else {
            print("✅ SyncQueueManager: Queue is empty")
            return
        }

        print("🔄 SyncQueueManager: Processing \(pending.count) pending operations")

        for operation in pending {
            await processOperation(operation)
        }

        print("✅ SyncQueueManager: Finished processing queue")
    }

    /// Process a single sync operation
    private func processOperation(_ operation: SyncOperation) async {
        do {
            print("🔄 Processing: \(operation.entityType) \(operation.operation) (ID: \(operation.entityId))")

            switch operation.entityType {
            case .cattle:
                try await processCattleOperation(operation)
            case .healthRecord:
                try await processHealthRecordOperation(operation)
            case .pregnancyRecord:
                try await processPregnancyRecordOperation(operation)
            case .calvingRecord:
                try await processCalvingRecordOperation(operation)
            case .saleRecord:
                try await processSaleRecordOperation(operation)
            case .processingRecord:
                try await processProcessingRecordOperation(operation)
            case .mortalityRecord:
                try await processMortalityRecordOperation(operation)
            case .stageTransition:
                try await processStageTransitionOperation(operation)
            case .photo:
                try await processPhotoOperation(operation)
            case .task:
                try await processTaskOperation(operation)
            case .contact:
                try await processContactOperation(operation)
            }

            // Success - remove from queue
            queue.remove(operation)
            print("✅ Completed: \(operation.entityType) \(operation.operation)")

        } catch {
            // Failure - record attempt
            let errorMessage = error.localizedDescription
            queue.recordFailure(for: operation, error: errorMessage)
            print("❌ Failed: \(operation.entityType) \(operation.operation) - \(errorMessage)")
        }
    }

    // MARK: - Operation Processors

    private func processCattleOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let cattle = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let cattle = cattle else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await cattleRepository.create(cattle)
        case .update:
            _ = try await cattleRepository.update(cattle)
        case .delete:
            try await cattleRepository.delete(operation.entityId)
        }
    }

    private func processHealthRecordOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let record = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let record = record else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await healthRecordRepository.create(record)
        case .update:
            _ = try await healthRecordRepository.update(record)
        case .delete:
            try await healthRecordRepository.delete(operation.entityId)
        }
    }

    private func processPregnancyRecordOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<PregnancyRecord> = PregnancyRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let record = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let record = record else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await pregnancyRecordRepository.create(record)
        case .update:
            _ = try await pregnancyRecordRepository.update(record)
        case .delete:
            try await pregnancyRecordRepository.delete(operation.entityId)
        }
    }

    private func processCalvingRecordOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<CalvingRecord> = CalvingRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let record = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let record = record else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await calvingRecordRepository.create(record)
        case .update:
            _ = try await calvingRecordRepository.update(record)
        case .delete:
            try await calvingRecordRepository.delete(operation.entityId)
        }
    }

    private func processSaleRecordOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<SaleRecord> = SaleRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let record = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let record = record else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await saleRecordRepository.create(record)
        case .update:
            _ = try await saleRecordRepository.update(record)
        case .delete:
            try await saleRecordRepository.delete(operation.entityId)
        }
    }

    private func processProcessingRecordOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<ProcessingRecord> = ProcessingRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let record = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let record = record else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await processingRecordRepository.create(record)
        case .update:
            _ = try await processingRecordRepository.update(record)
        case .delete:
            try await processingRecordRepository.delete(operation.entityId)
        }
    }

    private func processMortalityRecordOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<MortalityRecord> = MortalityRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let record = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let record = record else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await mortalityRecordRepository.create(record)
        case .update:
            _ = try await mortalityRecordRepository.update(record)
        case .delete:
            try await mortalityRecordRepository.delete(operation.entityId)
        }
    }

    private func processStageTransitionOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<StageTransition> = StageTransition.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let record = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let record = record else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await stageTransitionRepository.create(record)
        case .update:
            _ = try await stageTransitionRepository.update(record)
        case .delete:
            try await stageTransitionRepository.delete(operation.entityId)
        }
    }

    private func processPhotoOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let photo = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let photo = photo else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create, .update:
            try await photoRepository.pushToSupabase(photo)
        case .delete:
            try await photoRepository.delete(operation.entityId)
        }
    }

    private func processTaskOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let task = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let task = task else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create, .update:
            try await taskRepository.pushToSupabase(task)
        case .delete:
            try await taskRepository.delete(operation.entityId)
        }
    }

    private func processContactOperation(_ operation: SyncOperation) async throws {
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", operation.entityId as CVarArg)

        let contact = try await context.perform {
            try self.context.fetch(fetchRequest).first
        }

        guard let contact = contact else {
            throw SyncError.entityNotFound
        }

        switch operation.operation {
        case .create:
            _ = try await contactRepository.create(contact)
        case .update:
            _ = try await contactRepository.update(contact)
        case .delete:
            try await contactRepository.delete(operation.entityId)
        }
    }

    // MARK: - Helpers

    private func updateCounts() {
        pendingCount = queue.count
        failedCount = queue.failedCount
    }

    /// Clear all failed operations from queue
    func clearFailedOperations() {
        let allOps = queue.allOperations()
        for op in allOps where !op.shouldRetry {
            queue.remove(op)
        }
        updateCounts()
        print("🗑️ SyncQueueManager: Cleared \(failedCount) failed operations")
    }
}

// MARK: - Errors

enum SyncError: Error {
    case entityNotFound
    case networkUnavailable
    case maxRetriesExceeded
}
