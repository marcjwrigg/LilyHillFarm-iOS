//
//  Persistence.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

internal import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create preview breeds
        let angusBreed = Breed(context: viewContext)
        angusBreed.id = UUID()
        angusBreed.name = "Angus"
        angusBreed.category = BreedCategory.beef.rawValue
        angusBreed.isActive = true

        let herefordBreed = Breed(context: viewContext)
        herefordBreed.id = UUID()
        herefordBreed.name = "Hereford"
        herefordBreed.category = BreedCategory.beef.rawValue
        herefordBreed.isActive = true

        // Create preview cattle with diverse stages and paths
        // Bull for breeding
        let bull = Cattle(context: viewContext)
        bull.id = UUID()
        bull.tagNumber = "LHF-B001"
        bull.name = "Sample Bull"
        bull.sex = CattleSex.bull.rawValue
        bull.cattleType = CattleType.beef.rawValue
        bull.breed = angusBreed
        bull.dateOfBirth = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        bull.color = "Black"
        bull.currentStatus = CattleStatus.active.rawValue
        bull.currentStage = CattleStage.breeding.rawValue
        bull.productionPath = ProductionPath.breeding.rawValue
        bull.currentWeight = NSDecimalNumber(decimal: Decimal(1850))
        bull.createdAt = Date()
        bull.modifiedAt = Date()

        // Cow for breeding
        let cow = Cattle(context: viewContext)
        cow.id = UUID()
        cow.tagNumber = "LHF-C001"
        cow.name = "Sample Cow"
        cow.sex = CattleSex.cow.rawValue
        cow.cattleType = CattleType.beef.rawValue
        cow.breed = angusBreed
        cow.dateOfBirth = Calendar.current.date(byAdding: .year, value: -4, to: Date())
        cow.color = "Black"
        cow.currentStatus = CattleStatus.active.rawValue
        cow.currentStage = CattleStage.breeding.rawValue
        cow.productionPath = ProductionPath.breeding.rawValue
        cow.currentWeight = NSDecimalNumber(decimal: Decimal(1250))
        cow.createdAt = Date()
        cow.modifiedAt = Date()

        // Heifer for breeding
        let heifer = Cattle(context: viewContext)
        heifer.id = UUID()
        heifer.tagNumber = "LHF-H001"
        heifer.name = "Sample Heifer"
        heifer.sex = CattleSex.heifer.rawValue
        heifer.cattleType = CattleType.beef.rawValue
        heifer.breed = herefordBreed
        heifer.dateOfBirth = Calendar.current.date(byAdding: .month, value: -18, to: Date())
        heifer.color = "Red & White"
        heifer.currentStatus = CattleStatus.active.rawValue
        heifer.currentStage = CattleStage.breeding.rawValue
        heifer.productionPath = ProductionPath.breeding.rawValue
        heifer.currentWeight = NSDecimalNumber(decimal: Decimal(950))
        heifer.createdAt = Date()
        heifer.modifiedAt = Date()

        // Feeder steer for beef finishing
        let feeder = Cattle(context: viewContext)
        feeder.id = UUID()
        feeder.tagNumber = "LHF-F001"
        feeder.name = "Sample Feeder"
        feeder.sex = CattleSex.steer.rawValue
        feeder.cattleType = CattleType.beef.rawValue
        feeder.breed = angusBreed
        feeder.dateOfBirth = Calendar.current.date(byAdding: .month, value: -14, to: Date())
        feeder.color = "Black"
        feeder.currentStatus = CattleStatus.active.rawValue
        feeder.currentStage = CattleStage.feeder.rawValue
        feeder.productionPath = ProductionPath.beefFinishing.rawValue
        feeder.currentWeight = NSDecimalNumber(decimal: Decimal(850))
        feeder.finishingStartDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())
        feeder.createdAt = Date()
        feeder.modifiedAt = Date()

        // Calf
        let calf = Cattle(context: viewContext)
        calf.id = UUID()
        calf.tagNumber = "LHF-101"
        calf.name = "Sample Calf"
        calf.sex = CattleSex.heifer.rawValue
        calf.cattleType = CattleType.beef.rawValue
        calf.breed = herefordBreed
        calf.dateOfBirth = Calendar.current.date(byAdding: .month, value: -4, to: Date())
        calf.color = "Red & White"
        calf.currentStatus = CattleStatus.active.rawValue
        calf.currentStage = CattleStage.calf.rawValue
        calf.productionPath = ProductionPath.beefFinishing.rawValue
        calf.currentWeight = NSDecimalNumber(decimal: Decimal(300))
        calf.dam = cow
        calf.sire = bull
        calf.createdAt = Date()
        calf.modifiedAt = Date()

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "LilyHillFarm")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure persistent store for Supabase sync
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }

            // Enable automatic lightweight migration
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

            // Enable persistent history tracking for sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

            // Enable remote change notifications
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            print("📦 Core Data migration enabled - will automatically migrate from v1 to v2")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.

                 Check the error message to determine what the actual problem was.
                 */
                print("❌ Core Data Error: \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("✅ Core Data store loaded successfully")
                print("🔄 Supabase sync will be used for cloud synchronization")
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save Context

    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("❌ Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Batch Operations

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
