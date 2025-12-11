# iOS Sync Overhaul - Implementation Progress

**Date Started**: December 9, 2024
**Status**: Phase 1 Core Implementation Complete (70%)

## ✅ Completed Tasks

### 1. Core Data Model Version 2 Created
- ✅ Created `LilyHillFarm 2.xcdatamodel` with all necessary schema updates
- ✅ Updated `.xccurrentversion` to use new model
- ✅ Added `deletedAt: Date?` to ALL 14 entities:
  - Cattle, Breed, HealthRecord, CalvingRecord, PregnancyRecord
  - StageTransition, ProcessingRecord, SaleRecord, MortalityRecord
  - Photo, TreatmentPlan, TreatmentPlanStep, Task, Contact

### 2. Added Missing Fields to Cattle Entity
- ✅ `farmId: UUID?` - for multi-farm support
- ✅ `deletedAt: Date?` - for soft delete sync
- ✅ `location: Transformable [String]?` - array field matching Supabase
- ✅ `externalSireName: String?` - external sire tracking
- ✅ `externalSireRegistration: String?` - external sire registration

### 3. Added farmId to All Entities
All entities now have `farmId: UUID?` for proper data isolation

### 4. DTOs Updated
- ✅ **CattleDTO** - Complete with all new fields + deletedAt
- ✅ **HealthRecordDTO** - Added farmId + deletedAt
- ⏳ **Remaining 12 DTOs** need deletedAt + farmId added:
  - PregnancyRecordDTO
  - CalvingRecordDTO
  - SaleRecordDTO
  - ProcessingRecordDTO
  - MortalityRecordDTO
  - StageTransitionDTO
  - PhotoDTO
  - BreedDTO
  - TreatmentPlanDTO
  - TreatmentPlanStepDTO
  - TaskDTO (already has farmId, needs deletedAt)
  - ContactDTO (already has farmId, needs deletedAt)

### 5. BaseSyncManager - Critical Deletion Sync Implemented
✅ Implemented `syncWithDeletions()` method with:
- Last sync timestamp tracking (UserDefaults)
- Fetches active records (WHERE deleted_at IS NULL)
- Fetches deleted records since last sync
- Marks local records as deleted
- Handles orphaned records (in iOS but not on server)
- Proper farm filtering

## 🔨 Next Steps (Remaining Work)

### Priority 1: Complete DTO Updates (2-3 hours)
For each of the 12 remaining DTOs, add:

```swift
// In struct definition:
let farmId: UUID?
let deletedAt: String?

// In CodingKeys:
case farmId = "farm_id"
case deletedAt = "deleted_at"

// In init(from entity:) method:
self.farmId = entity.farmId
self.deletedAt = entity.deletedAt?.toISO8601String()

// In update(_ entity:) method:
entity.farmId = self.farmId
entity.deletedAt = self.deletedAt?.toDate()
```

**Files to update:**
1. `/Models/DTOs/PregnancyRecordDTO.swift`
2. `/Models/DTOs/CalvingRecordDTO.swift`
3. `/Models/DTOs/SaleRecordDTO.swift`
4. `/Models/DTOs/ProcessingRecordDTO.swift`
5. `/Models/DTOs/MortalityRecordDTO.swift`
6. `/Models/DTOs/StageTransitionDTO.swift`
7. `/Models/DTOs/PhotoDTO.swift`
8. `/Models/DTOs/BreedDTO.swift`
9. `/Models/DTOs/TreatmentPlanDTO.swift`
10. `/Models/DTOs/TreatmentPlanStepDTO.swift`
11. `/Models/DTOs/TaskDTO.swift` (add deletedAt only)
12. `/Models/DTOs/ContactDTO.swift` (add deletedAt only)

### Priority 2: Update CattleRepository (1 hour)
Replace existing `syncFromSupabase()` with the new deletion-aware sync:

```swift
func syncFromSupabase() async throws {
    try await syncWithDeletions(
        entityType: Cattle.self,
        tableName: "cattle",
        updateEntity: { (cattle: Cattle, dto: Any) in
            guard let dict = dto as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: dict),
                  let cattleDTO = try? JSONDecoder().decode(CattleDTO.self, from: data) else {
                throw RepositoryError.invalidData
            }
            cattleDTO.update(cattle)
        },
        extractId: { dto in
            guard let dict = dto as? [String: Any],
                  let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                return UUID() // Fallback
            }
            return id
        }
    )
}
```

### Priority 3: Create Farm Filtering Extension (30 minutes)
Create `/Extensions/NSFetchRequest+Filtering.swift`:

```swift
import CoreData

extension NSFetchRequest where ResultType: NSManagedObject {
    /// Apply farm and deletion filtering to fetch request
    /// Filters by: farm_id == current AND deleted_at == nil
    func filterByCurrentFarmAndActive(farmId: UUID) {
        let predicates = [
            NSPredicate(format: "farmId == %@", farmId as CVarArg),
            NSPredicate(format: "deletedAt == nil")
        ]

        if let existingPredicate = predicate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
                predicates + [existingPredicate])
        } else {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
}
```

### Priority 4: Update Remaining Repositories (3-4 hours)
Update all repositories to use `syncWithDeletions()`:
1. HealthRecordRepository
2. PregnancyRecordRepository
3. CalvingRecordRepository
4. SaleRecordRepository
5. ProcessingRecordRepository
6. MortalityRecordRepository
7. StageTransitionRepository
8. PhotoRepository
9. BreedRepository

### Priority 5: Update Delete Methods to Soft Delete (1 hour)
In each repository, update delete methods:

```swift
func delete(_ id: UUID) async throws {
    try requireAuth()

    // Soft delete on server
    let update = ["deleted_at": Date().ISO8601Format()]
    try await supabase.client
        .from(tableName)
        .update(update)
        .eq("id", value: id.uuidString)
        .execute()

    // Mark deleted locally
    let fetchRequest = NSFetchRequest<EntityType>(entityName: "EntityName")
    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

    if let entity = try context.fetch(fetchRequest).first {
        entity.deletedAt = Date()
        try context.save()
    }
}
```

### Priority 6: Update Persistence Controller for Migration (1 hour)
Add automatic migration support in `Persistence.swift`:

```swift
init(inMemory: Bool = false) {
    container = NSPersistentContainer(name: "LilyHillFarm")

    if !inMemory {
        let description = container.persistentStoreDescriptions.first

        // Enable automatic lightweight migration
        description?.setOption(true as NSNumber,
            forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber,
            forKey: NSInferMappingModelAutomaticallyOption)

        // Enable persistent history tracking for sync
        description?.setOption(true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey)
    }

    container.loadPersistentStores { description, error in
        if let error = error {
            fatalError("Core Data migration failed: \(error)")
        }
        print("✅ Core Data loaded: \(description)")
    }
}
```

## 📊 Estimated Time Remaining
- DTO updates: **2-3 hours**
- Repository updates: **4-5 hours**
- Testing & fixes: **2-3 hours**

**Total remaining: 8-11 hours**

## 🎯 Success Criteria
Once complete, the app will have:
- ✅ Proper deletion sync (no more ghost records)
- ✅ Multi-farm data isolation
- ✅ Accurate cattle counts
- ✅ No schema drift
- ✅ Backward compatible migration

## 🚨 Known Issues to Test
1. Migration from v1 to v2 with existing data
2. Handling records without farmId (set default)
3. Location array transformation
4. Sync performance with large datasets
5. Conflict resolution if editing during sync

## 📝 Migration Notes
- Migration is **lightweight** and **automatic**
- Existing records will have `deletedAt = nil` (active)
- Need to set default `farmId` for existing records on first sync
- Location field will be converted from String to array

## 🔧 Testing Checklist
- [ ] Fresh install works
- [ ] Upgrade from v1 preserves data
- [ ] Deletion sync removes deleted records
- [ ] Orphaned records are cleaned up
- [ ] Multi-farm filtering works
- [ ] Offline mode still functions
- [ ] Large dataset performance acceptable
