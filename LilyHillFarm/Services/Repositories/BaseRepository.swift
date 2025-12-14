//
//  BaseRepository.swift
//  LilyHillFarm
//
//  Base repository protocol for data sync operations
//

import Foundation
internal import CoreData
import Supabase

/// Protocol for repositories that sync with Supabase
protocol SupabaseRepository {
    associatedtype Entity: NSManagedObject
    associatedtype DTO: Codable

    /// Fetch all records from Supabase
    func fetchAll() async throws -> [DTO]

    /// Fetch a single record by ID
    func fetchById(_ id: UUID) async throws -> DTO?

    /// Create a new record in Supabase
    func create(_ dto: DTO) async throws -> DTO

    /// Update an existing record in Supabase
    func update(_ dto: DTO) async throws -> DTO

    /// Delete a record from Supabase
    func delete(_ id: UUID) async throws

    /// Sync local Core Data with Supabase
    func syncWithSupabase() async throws
}

/// Base sync manager with common functionality
class BaseSyncManager {
    let context: NSManagedObjectContext
    let supabase = SupabaseManager.shared

    /// Cached farm ID for current session
    private var _cachedFarmId: UUID?

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Save Core Data context
    func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    /// Get current user ID (required for all operations)
    var userId: UUID? {
        return supabase.userId
    }

    /// Get user's primary farm ID (cached after first fetch)
    func getFarmId() async throws -> UUID {
        // Return cached value if available
        if let cached = _cachedFarmId {
            return cached
        }

        // Fetch from database
        try requireAuth()

        guard let userId = userId else {
            throw RepositoryError.notAuthenticated
        }

        // Query farm_users table to get user's farm(s)
        struct FarmUser: Codable {
            let farm_id: UUID
        }

        guard let client = supabase.client else {
            throw RepositoryError.syncFailed("Supabase client not initialized")
        }

        let farmUsers: [FarmUser] = try await client
            .from("farm_users")
            .select("farm_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let farmId = farmUsers.first?.farm_id else {
            throw RepositoryError.syncFailed("No farm found for user. User must be added to a farm via farm_users table.")
        }

        // Cache it
        _cachedFarmId = farmId
        print("✅ Fetched farm_id: \(farmId)")

        return farmId
    }

    /// Check if user is authenticated
    func requireAuth() throws {
        guard supabase.isAuthenticated else {
            throw RepositoryError.notAuthenticated
        }
    }

    // MARK: - Deletion Sync

    /// Last sync timestamp storage key prefix
    private func lastSyncKey(for tableName: String) -> String {
        return "lastSync_\(tableName)"
    }

    /// Get last sync date for a table
    func getLastSyncDate(for tableName: String) -> Date? {
        let key = lastSyncKey(for: tableName)
        return UserDefaults.standard.object(forKey: key) as? Date
    }

    /// Set last sync date for a table
    func setLastSyncDate(_ date: Date, for tableName: String) {
        let key = lastSyncKey(for: tableName)
        UserDefaults.standard.set(date, forKey: key)
    }

    /// Clear last sync date for a table (force full sync on next attempt)
    func clearLastSyncDate(for tableName: String) {
        let key = lastSyncKey(for: tableName)
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Sync with deletion support - the new recommended sync method
    /// This method handles:
    /// 1. Fetching active records from Supabase
    /// 2. Fetching recently deleted records from Supabase
    /// 3. Creating/updating local records
    /// 4. Soft-deleting records that were deleted on server
    /// 5. Handling orphaned records (exist locally but not on server)
    func syncWithDeletions<T: NSManagedObject>(
        entityType: T.Type,
        tableName: String,
        updateEntity: @escaping (T, Any) throws -> Void,
        extractId: @escaping (Any) -> UUID,
        hasFarmId: Bool = true,
        supportsDeletes: Bool = true
    ) async throws {
        try requireAuth()

        let farmId = try await getFarmId()
        let lastSync = getLastSyncDate(for: tableName) ?? Date.distantPast

        print("🔄 Syncing \(tableName) with deletion support...")
        print("   Last sync: \(lastSync)")
        print("   Farm ID: \(farmId)")

        guard let client = supabase.client else {
            throw RepositoryError.syncFailed("Supabase client not initialized")
        }

        // 1. Fetch CHANGED/NEW records from Supabase (modified since last sync)
        print("   📥 Fetching records modified since \(lastSync)...")
        var activeQuery = client
            .from(tableName)
            .select()

        if hasFarmId {
            activeQuery = activeQuery.eq("farm_id", value: farmId.uuidString)
        }

        // Only filter by deleted_at if the table supports it
        if supportsDeletes {
            activeQuery = activeQuery.is("deleted_at", value: nil)
        }

        // INCREMENTAL SYNC: Only fetch records modified since last sync
        activeQuery = activeQuery.gte("updated_at", value: lastSync.ISO8601Format())

        let activeRecordsData = try await activeQuery
            .execute()
            .data

        let decoder = JSONDecoder()
        let activeRecords = try decoder.decode([AnyCodable].self, from: activeRecordsData)
        print("   ✅ Fetched \(activeRecords.count) modified/new records")

        // 2. Fetch records deleted since last sync (only if table supports deletes)
        var deletedRecords: [DeletedRecord] = []
        if supportsDeletes {
            print("   📥 Fetching deleted records since last sync...")
            var deletedQuery = client
                .from(tableName)
                .select("id, deleted_at")

            if hasFarmId {
                deletedQuery = deletedQuery.eq("farm_id", value: farmId.uuidString)
            }

            let deletedRecordsData = try await deletedQuery
                .gt("deleted_at", value: lastSync.ISO8601Format())
                .execute()
                .data

            deletedRecords = try decoder.decode([DeletedRecord].self, from: deletedRecordsData)
            print("   ✅ Found \(deletedRecords.count) deleted records")
        }

        // 3. Get all local record IDs for this farm
        try await context.perform { [weak self] in
            guard let self = self else { return }

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entityType))
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["id"]
            fetchRequest.predicate = NSPredicate(format: "farmId == %@ AND deletedAt == nil", farmId as CVarArg)

            let localRecords = try self.context.fetch(fetchRequest) as! [[String: Any]]
            let localIdSet = Set(localRecords.compactMap { $0["id"] as? UUID })

            print("   📊 Found \(localIdSet.count) local active records")

            // 4. Create/update active records in Core Data
            print("   💾 Updating local records...")
            for activeRecord in activeRecords {
                let recordId = extractId(activeRecord.value)

                let entityFetch = NSFetchRequest<T>(entityName: String(describing: entityType))
                entityFetch.predicate = NSPredicate(format: "id == %@", recordId as CVarArg)

                let entity: T
                if let existing = try self.context.fetch(entityFetch).first {
                    entity = existing
                } else {
                    entity = T(context: self.context)
                }

                // Update entity from DTO
                try updateEntity(entity, activeRecord.value)
            }

            // 5. Soft delete records that were deleted on server
            print("   🗑️ Marking \(deletedRecords.count) records as deleted...")
            for deletedRecord in deletedRecords {
                try self.markAsDeleted(id: deletedRecord.id, entityType: entityType)
            }

            // 6. Handle orphaned records (exist locally but not in server's active set)
            // Only do orphan detection if we fetched ALL records (not incremental sync)
            let isIncrementalSync = lastSync > Date.distantPast

            if !isIncrementalSync {
                let serverIdSet = Set(activeRecords.map { extractId($0.value) })
                let deletedIdSet = Set(deletedRecords.map { $0.id })
                let orphanedIds = localIdSet.subtracting(serverIdSet).subtracting(deletedIdSet)

                if !orphanedIds.isEmpty {
                    print("   ⚠️ Found \(orphanedIds.count) orphaned records")
                    print("   🗑️ Hard deleting orphaned records (not found on server)...")
                    for orphanedId in orphanedIds {
                        try self.hardDelete(id: orphanedId, entityType: entityType)
                    }
                }
            } else {
                print("   ℹ️ Skipping orphan detection (incremental sync)")
            }

            // 7. Save context
            print("   💾 Saving Core Data context...")
            try self.saveContext()

            print("   ✅ Sync completed for \(tableName)")
        }

        // 8. Update last sync timestamp
        setLastSyncDate(Date(), for: tableName)
    }

    /// Mark a record as deleted (soft delete)
    private func markAsDeleted<T: NSManagedObject>(id: UUID, entityType: T.Type) throws {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entityType))
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let entity = try context.fetch(fetchRequest).first {
            // Set deletedAt to current date
            entity.setValue(Date(), forKey: "deletedAt")
            print("   🗑️ Marked \(String(describing: entityType)) \(id) as deleted")
        }
    }

    /// Hard delete a record from Core Data (permanently remove)
    private func hardDelete<T: NSManagedObject>(id: UUID, entityType: T.Type) throws {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entityType))
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let entity = try context.fetch(fetchRequest).first {
            context.delete(entity)
            print("   🗑️ Hard deleted \(String(describing: entityType)) \(id)")
        }
    }
}

// MARK: - Helper Types

/// Helper for decoding and encoding any JSON value
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Could not decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode value"
                )
            )
        }
    }
}

/// Record representing a deleted item
struct DeletedRecord: Codable {
    let id: UUID
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deletedAt = "deleted_at"
    }
}

/// Common repository errors
enum RepositoryError: LocalizedError {
    case notAuthenticated
    case notFound
    case invalidData
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .notFound:
            return "Record not found"
        case .invalidData:
            return "Invalid data format"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

/// Sync status tracking
enum SyncStatus {
    case idle
    case syncing
    case success
    case failed(Error)
}
