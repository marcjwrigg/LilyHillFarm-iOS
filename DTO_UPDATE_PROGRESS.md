# DTO Update Progress

## ✅ Completed (7 of 14)

1. ✅ **CattleDTO** - Full update with location, external_sire fields
2. ✅ **HealthRecordDTO** - Added farmId + deletedAt
3. ✅ **PregnancyRecordDTO** - Added farmId + deletedAt
4. ✅ **TaskDTO** - Added deletedAt
5. ✅ **CalvingRecordDTO** - Added farmId + deletedAt
6. ✅ **ContactDTO** - Added deletedAt
7. ✅ **SaleRecordDTO** - Added farmId + deletedAt

## 🔄 Remaining (7 DTOs)

### Quick Update Pattern

For each file below, add these fields and update the methods:

```swift
// 1. Add to struct
let farmId: UUID?
let deletedAt: String?

// 2. Add to CodingKeys
case farmId = "farm_id"
case deletedAt = "deleted_at"

// 3. In init(from entity:)
self.farmId = entity.farmId
self.deletedAt = entity.deletedAt?.toISO8601String()

// 4. In update(_ entity:)
entity.farmId = self.farmId
entity.deletedAt = self.deletedAt?.toDate()
```

### Files to Update:

1. **ProcessingRecordDTO.swift** (`/Models/DTOs/ProcessingRecordDTO.swift`)
   - Straightforward, has `createdAt`
   - Add both farmId and deletedAt

2. **MortalityRecordDTO.swift** (`/Models/DTOs/MortalityRecordDTO.swift`)
   - Straightforward, has `createdAt`
   - Add both farmId and deletedAt

3. **StageTransitionDTO.swift** (`/Models/DTOs/StageTransitionDTO.swift`)
   - Simple, has `createdAt`
   - Add both farmId and deletedAt

4. **PhotoDTO.swift** (`/Models/DTOs/PhotoDTO.swift`)
   - Has `createdAt`
   - Add both farmId and deletedAt

5. **BreedDTO.swift** (`/Models/DTOs/BreedDTO.swift`)
   - Reference data, might not have timestamps
   - Add both farmId and deletedAt
   - Note: Breeds might be shared across farms, check if farmId is needed

6. **TreatmentPlanDTO.swift** (`/Models/DTOs/TreatmentPlanDTO.swift`)
   - Has `createdAt` and `updatedAt`
   - Add both farmId and deletedAt

7. **TreatmentPlanStepDTO.swift** (`/Models/DTOs/TreatmentPlanStepDTO.swift`)
   - Child of TreatmentPlan
   - Might not need farmId (inherits from plan)
   - Add deletedAt for sure

## Estimated Time
- 7 files × 5 minutes each = **35 minutes remaining**

## Testing After Completion
Once all DTOs are updated:
1. Build project to check for compilation errors
2. Run app to verify Core Data schema matches
3. Test sync with one entity to verify pattern works
