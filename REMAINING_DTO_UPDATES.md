# Remaining DTO Updates - Quick Reference

## Completed DTOs ✅
1. CattleDTO - ✅ Complete (with location, external_sire fields)
2. HealthRecordDTO - ✅ Complete
3. PregnancyRecordDTO - ✅ Complete
4. TaskDTO - ✅ Complete

## Remaining DTOs to Update (8 files)

For each DTO below, follow this exact pattern:

### 1. Add fields to struct
```swift
let farmId: UUID?
let deletedAt: String?  // For soft delete sync
```

### 2. Add to CodingKeys enum
```swift
case farmId = "farm_id"
case deletedAt = "deleted_at"
```

### 3. Add to memberwise init (if exists)
Add `farmId: UUID?` and `deletedAt: String?` parameters and assignments

### 4. Add to custom decoder (if exists)
```swift
self.farmId = try? container.decodeIfPresent(UUID.self, forKey: .farmId)
self.deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
```

### 5. Update init(from entity:) method
```swift
self.farmId = entity.farmId
self.deletedAt = entity.deletedAt?.toISO8601String()
```

### 6. Update update(_ entity:) method
```swift
entity.farmId = self.farmId
entity.deletedAt = self.deletedAt?.toDate()
```

---

## Files to Update:

### 1. CalvingRecordDTO.swift
Location: `/Models/DTOs/CalvingRecordDTO.swift`
- Has `createdAt` field already
- Add `farmId` and `deletedAt` before `createdAt`

### 2. SaleRecordDTO.swift
Location: `/Models/DTOs/SaleRecordDTO.swift`
- Has `createdAt` field already
- Add `farmId` and `deletedAt` before `createdAt`

### 3. ProcessingRecordDTO.swift
Location: `/Models/DTOs/ProcessingRecordDTO.swift`
- Has `createdAt` field already
- Add `farmId` and `deletedAt` before `createdAt`

### 4. MortalityRecordDTO.swift
Location: `/Models/DTOs/MortalityRecordDTO.swift`
- Has `createdAt` field already
- Add `farmId` and `deletedAt` before `createdAt`

### 5. StageTransitionDTO.swift
Location: `/Models/DTOs/StageTransitionDTO.swift`
- Has `createdAt` field already
- Add `farmId` and `deletedAt` before `createdAt`

### 6. PhotoDTO.swift
Location: `/Models/DTOs/PhotoDTO.swift`
- Has `createdAt` field already
- Add `farmId` and `deletedAt` before `createdAt`

### 7. BreedDTO.swift
Location: `/Models/DTOs/BreedDTO.swift`
- Might not have timestamp fields
- Add `farmId` and `deletedAt` at end

### 8. TreatmentPlanDTO.swift
Location: `/Models/DTOs/TreatmentPlanDTO.swift`
- Has `createdAt` and `updatedAt` fields
- Add `farmId` and `deletedAt` before `createdAt`

### 9. TreatmentPlanStepDTO.swift
Location: `/Models/DTOs/TreatmentPlanStepDTO.swift`
- Has `createdAt` field
- Add `farmId` and `deletedAt` before `createdAt`
- Note: Might not need `farmId` since it's child of TreatmentPlan

### 10. ContactDTO.swift
Location: `/Models/DTOs/ContactDTO.swift`
- Already has `farmId` - just add `deletedAt`
- Has `createdAt` and `modifiedAt`
- Add `deletedAt` before `createdAt`

---

## Example: Complete Update for CalvingRecordDTO

```swift
struct CalvingRecordDTO: Codable {
    let id: UUID
    let damId: UUID
    let sireId: UUID?
    let calfId: UUID?
    let farmId: UUID?  // ADD THIS
    let calvingDate: String?
    let difficulty: String?
    let calfSex: String?
    let calfBirthWeight: Double?
    // ... other fields ...
    let notes: String?
    let deletedAt: String?  // ADD THIS
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case damId = "dam_id"
        case sireId = "sire_id"
        case calfId = "calf_id"
        case farmId = "farm_id"  // ADD THIS
        case calvingDate = "calving_date"
        case difficulty
        case calfSex = "calf_sex"
        case calfBirthWeight = "calf_birth_weight"
        // ... other cases ...
        case notes
        case deletedAt = "deleted_at"  // ADD THIS
        case createdAt = "created_at"
    }
}

extension CalvingRecordDTO {
    init(from record: CalvingRecord) {
        self.id = record.id ?? UUID()
        self.damId = record.dam?.id ?? UUID()
        self.sireId = record.sire?.id
        self.calfId = record.calf?.id
        self.farmId = record.farmId  // ADD THIS
        self.calvingDate = record.calvingDate?.toISO8601String()
        // ... other field assignments ...
        self.notes = record.notes
        self.deletedAt = record.deletedAt?.toISO8601String()  // ADD THIS
        self.createdAt = record.createdAt?.toISO8601String()
    }

    func update(_ record: CalvingRecord) {
        record.id = self.id
        record.farmId = self.farmId  // ADD THIS
        record.calvingDate = self.calvingDate?.toDate()
        // ... other field assignments ...
        record.notes = self.notes
        record.deletedAt = self.deletedAt?.toDate()  // ADD THIS
        record.createdAt = self.createdAt?.toDate()
    }
}
```

---

## Priority Order
1. CalvingRecordDTO (most complex relationships)
2. SaleRecordDTO
3. ProcessingRecordDTO
4. MortalityRecordDTO
5. StageTransitionDTO
6. PhotoDTO
7. BreedDTO
8. TreatmentPlanDTO
9. TreatmentPlanStepDTO
10. ContactDTO (easiest - only needs deletedAt)

**Estimated time: 1-2 hours for all 10 files**
