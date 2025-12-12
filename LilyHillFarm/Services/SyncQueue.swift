//
//  SyncQueue.swift
//  LilyHillFarm
//
//  Data structures for persistent sync queue
//

import Foundation

/// Represents a sync operation that needs to be performed
struct SyncOperation: Codable, Identifiable {
    let id: UUID
    let entityType: EntityType
    let entityId: UUID
    let operation: OperationType
    let timestamp: Date
    var retryCount: Int
    var lastAttempt: Date?
    var error: String?

    init(entityType: EntityType, entityId: UUID, operation: OperationType) {
        self.id = UUID()
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.timestamp = Date()
        self.retryCount = 0
        self.lastAttempt = nil
        self.error = nil
    }

    /// Entity types that can be synced
    enum EntityType: String, Codable {
        case cattle
        case healthRecord
        case pregnancyRecord
        case calvingRecord
        case saleRecord
        case processingRecord
        case mortalityRecord
        case stageTransition
        case photo
        case task
        case contact
    }

    /// Types of operations
    enum OperationType: String, Codable {
        case create
        case update
        case delete
    }

    /// Maximum number of retry attempts
    static let maxRetries = 5

    /// Check if operation should be retried
    var shouldRetry: Bool {
        return retryCount < Self.maxRetries
    }

    /// Calculate next retry delay using exponential backoff
    var nextRetryDelay: TimeInterval {
        // Exponential backoff: 2^retryCount seconds
        // 0 retries: 1 second
        // 1 retry: 2 seconds
        // 2 retries: 4 seconds
        // 3 retries: 8 seconds
        // 4 retries: 16 seconds
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 60.0 // Cap at 1 minute
        let delay = baseDelay * pow(2.0, Double(retryCount))
        return min(delay, maxDelay)
    }

    /// Check if enough time has passed since last attempt to retry
    func canRetryNow() -> Bool {
        guard let lastAttempt = lastAttempt else {
            return true // No previous attempt
        }

        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
        return timeSinceLastAttempt >= nextRetryDelay
    }

    /// Record a failed attempt
    mutating func recordFailure(error: String) {
        self.retryCount += 1
        self.lastAttempt = Date()
        self.error = error
    }
}

/// Persistent queue for sync operations
class SyncQueue {
    // MARK: - Storage

    private let userDefaultsKey = "com.lilyhillfarm.syncQueue"
    private var operations: [SyncOperation] = []

    // MARK: - Initialization

    init() {
        load()
    }

    // MARK: - Queue Operations

    /// Add operation to queue
    func enqueue(_ operation: SyncOperation) {
        // Check if this operation already exists in queue
        if let existingIndex = operations.firstIndex(where: {
            $0.entityType == operation.entityType &&
            $0.entityId == operation.entityId &&
            $0.operation == operation.operation
        }) {
            // Replace existing operation with new one (fresher data)
            operations[existingIndex] = operation
            print("🔄 SyncQueue: Updated existing operation - \(operation.entityType) \(operation.operation)")
        } else {
            operations.append(operation)
            print("➕ SyncQueue: Added operation - \(operation.entityType) \(operation.operation)")
        }

        save()
    }

    /// Get all pending operations
    func pendingOperations() -> [SyncOperation] {
        return operations.filter { $0.shouldRetry && $0.canRetryNow() }
    }

    /// Get all operations (including failed)
    func allOperations() -> [SyncOperation] {
        return operations
    }

    /// Remove operation from queue
    func remove(_ operation: SyncOperation) {
        operations.removeAll { $0.id == operation.id }
        save()
        print("✅ SyncQueue: Removed operation - \(operation.entityType) \(operation.operation)")
    }

    /// Record failed attempt for operation
    func recordFailure(for operation: SyncOperation, error: String) {
        if let index = operations.firstIndex(where: { $0.id == operation.id }) {
            operations[index].recordFailure(error: error)
            save()

            if operations[index].shouldRetry {
                print("⚠️ SyncQueue: Operation failed (attempt \(operations[index].retryCount)/\(SyncOperation.maxRetries)) - \(operation.entityType) \(operation.operation)")
            } else {
                print("❌ SyncQueue: Operation failed permanently after \(operations[index].retryCount) attempts - \(operation.entityType) \(operation.operation)")
            }
        }
    }

    /// Clear all operations
    func clear() {
        operations.removeAll()
        save()
        print("🗑️ SyncQueue: Cleared all operations")
    }

    /// Get count of pending operations
    var count: Int {
        return pendingOperations().count
    }

    /// Get count of permanently failed operations
    var failedCount: Int {
        return operations.filter { !$0.shouldRetry }.count
    }

    // MARK: - Persistence

    /// Save queue to UserDefaults
    private func save() {
        do {
            let data = try JSONEncoder().encode(operations)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("💾 SyncQueue: Saved \(operations.count) operations to disk")
        } catch {
            print("❌ SyncQueue: Failed to save queue - \(error)")
        }
    }

    /// Load queue from UserDefaults
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            print("📭 SyncQueue: No saved operations found")
            return
        }

        do {
            operations = try JSONDecoder().decode([SyncOperation].self, from: data)
            print("📥 SyncQueue: Loaded \(operations.count) operations from disk")
        } catch {
            print("❌ SyncQueue: Failed to load queue - \(error)")
            operations = []
        }
    }
}
