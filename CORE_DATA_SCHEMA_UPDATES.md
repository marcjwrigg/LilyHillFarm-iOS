# Core Data Schema Updates for Supabase Migration

This document outlines all required changes to the Core Data schema. **These changes must be made in Xcode's Core Data Model Editor.**

---

## How to Update the Schema

1. Open `LilyHillFarm.xcodeproj` in Xcode
2. Navigate to `LilyHillFarm.xcdatamodeld`
3. Select the entity you want to modify
4. Use the Attributes/Relationships panels on the right to add/modify fields
5. Create a new model version for migration:
   - **Editor → Add Model Version...**
   - Name it `LilyHillFarm 2`
   - Set as current version in `.xccurrentversion`

---

## 1. Cattle Entity Updates

### Add Attributes:

| Attribute Name | Type | Optional | Default | Notes |
|----------------|------|----------|---------|-------|
| `userId` | UUID | NO | - | Required for RLS - links to Supabase user |
| `pastureId` | UUID | YES | - | Future use - web manages this |

### Modify Attributes:

| Attribute Name | Change | Notes |
|----------------|--------|-------|
| `tags` | Change from String to Transformable (String array) | Use `NSSecureUnarchiveFromDataTransformer` |

### Update Enums (validation in code):

**Sex:**
- Remove: `Calf` (it's a stage, not a sex)
- Keep: `Bull`, `Cow`, `Heifer`, `Steer`

**Stage:**
- Remove: `Yearling`, `Finished`
- Add: `Stocker`, `Feeder`
- Keep: `Calf`, `Weanling`, `Heifer`, `Cow`, `Bull`, `Steer`, `Processed`

**ProductionPath:**
- Add: `Breeding`, `Market`, `Replacement`
- Keep: `BeefFinishing`

---

## 2. HealthRecord Entity Updates

### Add Attributes:

| Attribute Name | Type | Optional | Default | Notes |
|----------------|------|----------|---------|-------|
| `treatmentPlanId` | UUID | YES | - | Links to treatment_plans table |

### No changes needed:
All other fields align with Supabase schema.

---

## 3. CalvingRecord Entity Updates

### Add Attributes:

| Attribute Name | Type | Optional | Default | Notes |
|----------------|------|----------|---------|-------|
| `pregnancyId` | UUID | YES | - | Links to pregnancy_records |
| `retainedPlacenta` | Boolean | YES | false | Important health metric |

### Rename/Map (handle in sync code):

| Old Name | Maps to Supabase | Notes |
|----------|------------------|-------|
| `difficulty` | `calvingEase` | Different field name |
| `calfBirthWeight` | `birthWeight` | Simplified name |
| `calfStatus` | `calfVigor` | Different concept - see enum updates |

### Remove Attributes:

- `calfWeightAtWeaning` - Belongs in cattle or stage_transition
- `weaningNotes` - Not tracked in Supabase

### Remove Relationships:

- `sire` - Use pregnancy record instead

### Update Enums:

**CalvingEase (was difficulty):**
- `Unassisted`
- `Easy Pull`
- `Hard Pull`
- `Caesarean`
- `Other`

**CalfVigor (was calfStatus):**
- Remove: `Alive`, `Dead`
- Add: `Excellent`, `Good`, `Fair`, `Poor`, `Stillborn`

---

## 4. PregnancyRecord Entity Updates

### Add Attributes:

| Attribute Name | Type | Optional | Default | Notes |
|----------------|------|----------|---------|-------|
| `breedingStartDate` | Date | YES | - | Breeding season tracking |
| `breedingEndDate` | Date | YES | - | Breeding season tracking |
| `expectedCalvingStartDate` | Date | YES | - | Calving season range |
| `expectedCalvingEndDate` | Date | YES | - | Calving season range |

### Remove Attributes:

- `outcome` - Not in Supabase
- `modifiedAt` - Not tracked in Supabase

### Update Enums:

**Status:**
- Change to lowercase: `bred`, `open`, `exposed`, `confirmed`, `calved`, `lost`
- Add: `open`, `exposed`, `calved`, `lost`

---

## 5. Photo Entity Updates

### Modify Attributes:

| Attribute Name | Change | Notes |
|----------------|--------|-------|
| `imageAssetPath` | Rename to `url` | Will store Supabase Storage URL |
| `thumbnailData` | Rename to `thumbnailUrl` | Will store URL instead of binary |

### Add Attributes:

| Attribute Name | Type | Optional | Default | Notes |
|----------------|------|----------|---------|-------|
| `url` | String | NO | - | Supabase Storage URL |
| `thumbnailUrl` | String | YES | - | Thumbnail URL |

### Remove Attributes:

- `dateTaken` - Use `createdAt` instead
- `fileSize` - Not tracked in Supabase
- `thumbnailData` (Binary) - Replaced with URL

### Remove Relationships:

- `calvingRecord`
- `pregnancyRecord`
- `processingRecord`
- `saleRecord`
- `mortalityRecord`

### Keep Relationships:

- `cattle`
- `healthRecord`

---

## 6. MortalityRecord Entity Updates

### Add Attributes:

| Attribute Name | Type | Optional | Default | Notes |
|----------------|------|----------|---------|-------|
| `veterinarianCalled` | Boolean | YES | false | Track if vet was called |

### Rename/Map (handle in sync code):

| Old Name | Maps to Supabase | Notes |
|----------|------------------|-------|
| `causeCategory` | `category` | Simplified name |
| `veterinarian` | `veterinarianName` | Clarified name |

### Remove Attributes:

- `necropsyPerformed` - Not in Supabase
- `necropsyResults` - Not in Supabase (put in notes)
- `reportedToAuthorities` - Not in Supabase

---

## 7. SaleRecord Entity Updates

### Modify Attributes:

| Attribute Name | Change | Notes |
|----------------|--------|-------|
| `buyer` | Change from String to UUID | Will store buyer_id FK |

### Remove Attributes:

- `buyerContact` - Handled via contacts table (web only)
- `paymentMethod` - Not in Supabase
- `marketType` - Not in Supabase

---

## 8. StageTransition Entity Updates

### Remove Attributes:

- `reason` - Put in notes if needed
- `recordedBy` - Tracked via RLS user_id

---

## 9. Breed Entity Updates (Read-Only)

### Remove Attributes:

- `category` - Not in Supabase
- `isActive` - Not in Supabase

### Keep:
- `id`
- `name`
- `characteristics`

---

## 10. NEW: Task Entity (Create from scratch)

### Attributes:

| Attribute Name | Type | Optional | Default | Notes |
|----------------|------|----------|---------|-------|
| `id` | UUID | NO | - | Primary key |
| `userId` | UUID | NO | - | Owner (for RLS) |
| `title` | String | NO | - | Task title |
| `taskDescription` | String | YES | - | Detailed description |
| `taskType` | String | NO | - | See enum below |
| `priority` | String | NO | `medium` | See enum below |
| `status` | String | NO | `pending` | See enum below |
| `dueDate` | Date | YES | - | When task is due |
| `assignedTo` | UUID | YES | - | Optional assignment |
| `completedAt` | Date | YES | - | When task was completed |
| `completedBy` | UUID | YES | - | Who completed it |
| `notes` | String | YES | - | Additional notes |
| `createdAt` | Date | NO | now | Creation timestamp |
| `updatedAt` | Date | NO | now | Last update timestamp |

### Relationships:

| Relationship Name | Destination | Type | Optional | Delete Rule |
|-------------------|-------------|------|----------|-------------|
| `cattle` | Cattle | To One | YES | Nullify |
| `healthRecord` | HealthRecord | To One | YES | Nullify |

### Enums:

**TaskType:**
- `health_followup`
- `breeding`
- `feeding`
- `maintenance`
- `general`
- `other`

**Priority:**
- `low`
- `medium`
- `high`
- `urgent`

**Status:**
- `pending`
- `in_progress`
- `completed`
- `cancelled`

---

## 11. NEW: TreatmentPlan Entity (Read-Only Reference Data)

### Attributes:

| Attribute Name | Type | Optional | Notes |
|----------------|------|----------|-------|
| `id` | UUID | NO | Primary key |
| `name` | String | NO | Plan name |
| `conditionType` | String | YES | What condition it treats |
| `planDescription` | String | YES | Description |
| `isActive` | Boolean | NO | Is this plan active |
| `createdAt` | Date | NO | Creation timestamp |

### Relationships:

| Relationship Name | Destination | Type | Delete Rule |
|-------------------|-------------|------|-------------|
| `steps` | TreatmentPlanStep | To Many | Cascade |

---

## 12. NEW: TreatmentPlanStep Entity (Read-Only Reference Data)

### Attributes:

| Attribute Name | Type | Optional | Notes |
|----------------|------|----------|-------|
| `id` | UUID | NO | Primary key |
| `dayNumber` | Integer 16 | NO | Day in sequence |
| `medication` | String | YES | Medication name |
| `dosage` | String | YES | Dosage amount |
| `administrationMethod` | String | YES | How to administer |
| `instructions` | String | YES | Detailed instructions |
| `notes` | String | YES | Additional notes |
| `sortOrder` | Integer 16 | NO | Display order |

### Relationships:

| Relationship Name | Destination | Type | Delete Rule |
|-------------------|-------------|------|-------------|
| `treatmentPlan` | TreatmentPlan | To One | Nullify |

---

## 13. NEW: HealthRecordType Entity (Read-Only Reference Data)

### Attributes:

| Attribute Name | Type | Optional | Notes |
|----------------|------|----------|-------|
| `id` | UUID | NO | Primary key |
| `name` | String | NO | Type name |
| `icon` | String | YES | Icon name |
| `color` | String | YES | Color code |
| `typeDescription` | String | YES | Description |
| `isActive` | Boolean | NO | Is active |

---

## 14. NEW: HealthCondition Entity (Read-Only Reference Data)

### Attributes:

| Attribute Name | Type | Optional | Notes |
|----------------|------|----------|-------|
| `id` | UUID | NO | Primary key |
| `name` | String | NO | Condition name |
| `conditionDescription` | String | YES | Description |
| `isActive` | Boolean | NO | Is active |

---

## 15. NEW: Medication Entity (Read-Only Reference Data)

### Attributes:

| Attribute Name | Type | Optional | Notes |
|----------------|------|----------|-------|
| `id` | UUID | NO | Primary key |
| `name` | String | NO | Medication name |
| `medicationType` | String | YES | Type (antibiotic, etc) |
| `dosageInfo` | String | YES | Standard dosage |
| `withdrawalPeriod` | String | YES | Withdrawal period |
| `notes` | String | YES | Additional info |

---

## Core Data Migration Steps

### Step 1: Create New Model Version

1. In Xcode, select `LilyHillFarm.xcdatamodeld`
2. Go to **Editor → Add Model Version...**
3. Name: `LilyHillFarm 2`
4. Based on: `LilyHillFarm`
5. Click **Finish**

### Step 2: Set Current Version

1. Select the `.xcdatamodeld` file (parent level)
2. In File Inspector (right panel), under **Versioned Core Data Model**
3. Set **Current** to `LilyHillFarm 2`

### Step 3: Make Schema Changes

Follow the changes outlined above for each entity.

### Step 4: Create Mapping Model (if needed)

For simple additive changes (adding fields), Core Data can infer mappings automatically. For complex changes:

1. **File → New → File...**
2. Choose **Mapping Model**
3. Source: `LilyHillFarm`
4. Destination: `LilyHillFarm 2`
5. Xcode will auto-generate mappings
6. Customize if needed

### Step 5: Update Persistence.swift

Add migration code:

```swift
// In PersistenceController.shared initialization
container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
```

### Step 6: Test Migration

1. Run app on device/simulator with old data
2. Verify migration completes successfully
3. Check that all data is preserved
4. Verify new fields are present

---

## Entity Extensions to Update

After schema changes, update these extension files:

1. `Models/Cattle+Extensions.swift` - Add userId, update tags handling
2. `Models/CalvingRecord+Extensions.swift` - Update field mappings
3. `Models/PregnancyRecord+Extensions.swift` - Add breeding season fields
4. `Models/Photo+Extensions.swift` - Update URL handling
5. `Models/MortalityRecord+Extensions.swift` - Update field mappings
6. `Models/SaleRecord+Extensions.swift` - Update buyer handling

**NEW FILES NEEDED:**
7. `Models/Task+Extensions.swift` - Create new
8. `Models/TreatmentPlan+Extensions.swift` - Create new
9. `Models/HealthRecordType+Extensions.swift` - Create new
10. `Models/HealthCondition+Extensions.swift` - Create new
11. `Models/Medication+Extensions.swift` - Create new

---

## Summary of Changes

### Entities to Update:
- ✏️ Cattle (add userId, pastureId, update tags)
- ✏️ HealthRecord (add treatmentPlanId)
- ✏️ CalvingRecord (add pregnancyId, retainedPlacenta; remove fields)
- ✏️ PregnancyRecord (add breeding season fields; remove fields)
- ✏️ Photo (change to URLs; remove relationships/fields)
- ✏️ MortalityRecord (add veterinarianCalled; remove fields)
- ✏️ SaleRecord (change buyer to UUID; remove fields)
- ✏️ StageTransition (remove fields)
- ✏️ Breed (remove fields)

### Entities to Create:
- ✨ Task (completely new - critical!)
- ✨ TreatmentPlan (read-only reference)
- ✨ TreatmentPlanStep (read-only reference)
- ✨ HealthRecordType (read-only reference)
- ✨ HealthCondition (read-only reference)
- ✨ Medication (read-only reference)

**Total:** 9 entities updated, 6 entities created

---

## Next Steps After Schema Updates

1. Create Swift extensions for new entities
2. Implement Supabase sync repositories
3. Add Realtime subscriptions
4. Update UI to use new fields
5. Test data migration thoroughly
