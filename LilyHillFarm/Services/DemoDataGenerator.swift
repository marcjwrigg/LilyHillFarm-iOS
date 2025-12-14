//
//  DemoDataGenerator.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

class DemoDataGenerator {
    private let context: NSManagedObjectContext
    private var angusBreed: Breed!
    private var bulls: [Cattle] = []
    private var cows: [Cattle] = []

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Main Generation

    func generateCompleteHerd() throws {
        // Create Angus breed
        angusBreed = createAngusBreed()

        // Create bulls
        bulls = createBulls(count: 5)

        // Create cows at various stages
        cows = createCows(count: 25)

        // Create calves
        let calves = createCalves(count: 20)

        // Create weanlings
        let weanlings = createWeanlings(count: 15)

        // Create feeders
        let feeders = createFeeders(count: 12)

        // Create heifers
        let heifers = createHeifers(count: 10)

        // Create processed cattle
        let processed = createProcessedCattle(count: 8)

        // Create sold cattle
        let sold = createSoldCattle(count: 10)

        // Create deceased cattle
        let deceased = createDeceasedCattle(count: 6)

        let allCattle = bulls + cows + calves + weanlings + feeders + heifers + processed + sold + deceased

        // Add health records to random cattle
        addHealthRecords(to: allCattle.filter { $0.currentStatus == CattleStatus.active.rawValue }, count: 30)

        // Add pregnancies to cows
        addPregnancies(to: cows, count: 25)

        // Add calving records
        addCalvingRecords(to: cows, calves: calves, count: 22)

        // Add processing records
        addProcessingRecords(to: processed)

        // Add sale records
        addSaleRecords(to: sold)

        // Add mortality records
        addMortalityRecords(to: deceased)

        // Save everything
        try context.save()

        print("✅ Demo data generated: \(bulls.count) bulls, \(cows.count) cows, \(heifers.count) heifers, \(calves.count) calves, \(weanlings.count) weanlings, \(feeders.count) feeders, \(processed.count) processed, \(sold.count) sold, \(deceased.count) deceased")
    }

    // MARK: - Breed Creation

    private func createAngusBreed() -> Breed {
        let breed = Breed(context: context)
        breed.id = UUID()
        breed.name = "Angus"
        breed.category = BreedCategory.beef.rawValue
        breed.characteristics = "Excellent marbling, docile temperament, maternal qualities, good feed efficiency"
        breed.isActive = true
        return breed
    }

    // MARK: - Cattle Creation

    private func createBulls(count: Int) -> [Cattle] {
        var bulls: [Cattle] = []
        let bullNames = ["Duke", "Thunder", "Rocky", "Max", "Bruno", "Titan", "Atlas", "Zeus", "Apollo", "Hercules"]

        for i in 1...count {
            let bull = Cattle.create(in: context)
            bull.tagNumber = "LHF-B\(String(format: "%03d", i))"
            bull.name = i <= bullNames.count ? bullNames[i - 1] : "Bull \(i)"
            bull.sex = CattleSex.bull.rawValue
            bull.breed = angusBreed
            bull.cattleType = CattleType.beef.rawValue
            bull.color = "Black"
            bull.dateOfBirth = Calendar.current.date(byAdding: .year, value: -(2 + (i % 5)), to: Date())
            bull.currentStatus = CattleStatus.active.rawValue
            bull.currentStage = LegacyCattleStage.breeding.rawValue
            bull.productionPath = LegacyProductionPath.breeding.rawValue
            bull.currentWeight = NSDecimalNumber(decimal: Decimal(1800 + (i * 50)))
            bull.createdAt = Date()
            bull.modifiedAt = Date()

            bulls.append(bull)
        }

        return bulls
    }

    private func createCows(count: Int) -> [Cattle] {
        var cows: [Cattle] = []
        let cowNames = ["Bessie", "Daisy", "Rosie", "Bella", "Molly", "Lucy", "Ruby", "Sadie", "Penny", "Willow",
                        "Hazel", "Clover", "Buttercup", "Pearl", "Marigold", "Iris", "Violet", "Lily", "Poppy", "Magnolia",
                        "Jasmine", "Dahlia", "Zinnia", "Petunia", "Tulip"]

        for i in 1...count {
            let cow = Cattle.create(in: context)
            cow.tagNumber = "LHF-C\(String(format: "%03d", i))"
            cow.name = i <= cowNames.count ? cowNames[i - 1] : "Cow \(i)"
            cow.sex = CattleSex.cow.rawValue
            cow.breed = angusBreed
            cow.cattleType = CattleType.beef.rawValue
            cow.color = "Black"
            cow.dateOfBirth = Calendar.current.date(byAdding: .year, value: -(2 + (i % 6)), to: Date())
            cow.currentStatus = CattleStatus.active.rawValue
            cow.currentStage = LegacyCattleStage.breeding.rawValue
            cow.productionPath = LegacyProductionPath.breeding.rawValue
            cow.currentWeight = NSDecimalNumber(decimal: Decimal(1200 + (i * 20)))
            cow.createdAt = Date()
            cow.modifiedAt = Date()

            cows.append(cow)
        }

        return cows
    }

    private func createCalves(count: Int) -> [Cattle] {
        var calves: [Cattle] = []

        for i in 1...count {
            let calf = Cattle.create(in: context)
            calf.tagNumber = "LHF-\(String(format: "%03d", 100 + i))"
            calf.sex = i % 2 == 0 ? CattleSex.heifer.rawValue : CattleSex.bull.rawValue
            calf.breed = angusBreed
            calf.cattleType = CattleType.beef.rawValue
            calf.color = "Black"
            calf.dateOfBirth = Calendar.current.date(byAdding: .month, value: -(1 + (i % 4)), to: Date())
            calf.currentStatus = CattleStatus.active.rawValue
            calf.currentStage = LegacyCattleStage.calf.rawValue
            calf.productionPath = i % 3 == 0 ? LegacyProductionPath.breeding.rawValue : LegacyProductionPath.beefFinishing.rawValue
            calf.currentWeight = NSDecimalNumber(decimal: Decimal(200 + (i * 15)))
            calf.createdAt = Date()
            calf.modifiedAt = Date()

            // Assign random dam and sire
            if !cows.isEmpty && !bulls.isEmpty {
                calf.dam = cows.randomElement()
                calf.sire = bulls.randomElement()
            }

            calves.append(calf)
        }

        return calves
    }

    private func createWeanlings(count: Int) -> [Cattle] {
        var weanlings: [Cattle] = []

        for i in 1...count {
            let weanling = Cattle.create(in: context)
            weanling.tagNumber = "LHF-W\(String(format: "%03d", i))"
            weanling.sex = i % 2 == 0 ? CattleSex.heifer.rawValue : CattleSex.bull.rawValue
            weanling.breed = angusBreed
            weanling.cattleType = CattleType.beef.rawValue
            weanling.color = "Black"
            weanling.dateOfBirth = Calendar.current.date(byAdding: .month, value: -(7 + (i % 3)), to: Date())
            weanling.currentStatus = CattleStatus.active.rawValue
            weanling.currentStage = LegacyCattleStage.weanling.rawValue
            weanling.productionPath = i % 3 == 0 ? LegacyProductionPath.breeding.rawValue : LegacyProductionPath.beefFinishing.rawValue
            weanling.currentWeight = NSDecimalNumber(decimal: Decimal(450 + (i * 25)))
            weanling.createdAt = Date()
            weanling.modifiedAt = Date()

            if !cows.isEmpty && !bulls.isEmpty {
                weanling.dam = cows.randomElement()
                weanling.sire = bulls.randomElement()
            }

            weanlings.append(weanling)
        }

        return weanlings
    }

    private func createFeeders(count: Int) -> [Cattle] {
        var feeders: [Cattle] = []

        for i in 1...count {
            let feeder = Cattle.create(in: context)
            feeder.tagNumber = "LHF-F\(String(format: "%03d", i))"
            feeder.sex = i % 2 == 0 ? CattleSex.heifer.rawValue : CattleSex.steer.rawValue
            feeder.breed = angusBreed
            feeder.cattleType = CattleType.beef.rawValue
            feeder.color = "Black"
            feeder.dateOfBirth = Calendar.current.date(byAdding: .month, value: -(12 + (i % 6)), to: Date())
            feeder.currentStatus = CattleStatus.active.rawValue
            feeder.currentStage = LegacyCattleStage.feeder.rawValue
            feeder.productionPath = LegacyProductionPath.beefFinishing.rawValue
            feeder.currentWeight = NSDecimalNumber(decimal: Decimal(800 + (i * 40)))
            feeder.createdAt = Date()
            feeder.modifiedAt = Date()

            if !cows.isEmpty && !bulls.isEmpty {
                feeder.dam = cows.randomElement()
                feeder.sire = bulls.randomElement()
            }

            feeders.append(feeder)
        }

        return feeders
    }

    private func createHeifers(count: Int) -> [Cattle] {
        var heifers: [Cattle] = []

        for i in 1...count {
            let heifer = Cattle.create(in: context)
            heifer.tagNumber = "LHF-H\(String(format: "%03d", i))"
            heifer.sex = CattleSex.heifer.rawValue
            heifer.breed = angusBreed
            heifer.cattleType = CattleType.beef.rawValue
            heifer.color = "Black"
            heifer.dateOfBirth = Calendar.current.date(byAdding: .month, value: -(15 + (i % 6)), to: Date())
            heifer.currentStatus = CattleStatus.active.rawValue
            heifer.currentStage = LegacyCattleStage.breeding.rawValue
            heifer.productionPath = LegacyProductionPath.breeding.rawValue
            heifer.currentWeight = NSDecimalNumber(decimal: Decimal(900 + (i * 35)))
            heifer.createdAt = Date()
            heifer.modifiedAt = Date()

            if !cows.isEmpty && !bulls.isEmpty {
                heifer.dam = cows.randomElement()
                heifer.sire = bulls.randomElement()
            }

            heifers.append(heifer)
        }

        return heifers
    }

    private func createProcessedCattle(count: Int) -> [Cattle] {
        var processed: [Cattle] = []

        for i in 1...count {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-P\(String(format: "%03d", i))"
            animal.sex = i % 2 == 0 ? CattleSex.heifer.rawValue : CattleSex.bull.rawValue
            animal.breed = angusBreed
            animal.cattleType = CattleType.beef.rawValue
            animal.color = "Black"
            animal.dateOfBirth = Calendar.current.date(byAdding: .month, value: -(18 + (i % 8)), to: Date())
            animal.currentStatus = CattleStatus.processed.rawValue
            animal.currentStage = LegacyCattleStage.processed.rawValue
            animal.productionPath = LegacyProductionPath.beefFinishing.rawValue
            animal.currentWeight = NSDecimalNumber(decimal: Decimal(1100 + (i * 50)))
            animal.processingDate = Calendar.current.date(byAdding: .day, value: -(30 + i * 7), to: Date())
            animal.exitDate = animal.processingDate
            animal.exitReason = "Processed"
            animal.createdAt = Date()
            animal.modifiedAt = Date()

            if !cows.isEmpty && !bulls.isEmpty {
                animal.dam = cows.randomElement()
                animal.sire = bulls.randomElement()
            }

            processed.append(animal)
        }

        return processed
    }

    private func createSoldCattle(count: Int) -> [Cattle] {
        var sold: [Cattle] = []

        for i in 1...count {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-S\(String(format: "%03d", i))"
            animal.sex = i % 2 == 0 ? CattleSex.heifer.rawValue : CattleSex.bull.rawValue
            animal.breed = angusBreed
            animal.cattleType = CattleType.beef.rawValue
            animal.color = "Black"
            animal.dateOfBirth = Calendar.current.date(byAdding: .month, value: -(14 + (i % 10)), to: Date())
            animal.currentStatus = CattleStatus.sold.rawValue
            animal.currentStage = i % 3 == 0 ? LegacyCattleStage.feeder.rawValue : LegacyCattleStage.weanling.rawValue
            animal.productionPath = LegacyProductionPath.beefFinishing.rawValue
            animal.currentWeight = NSDecimalNumber(decimal: Decimal(850 + (i * 40)))
            animal.exitDate = Calendar.current.date(byAdding: .day, value: -(15 + i * 5), to: Date())
            animal.exitReason = "Sold"
            animal.salePrice = NSDecimalNumber(decimal: Decimal(Double.random(in: 800...1500)))
            animal.createdAt = Date()
            animal.modifiedAt = Date()

            if !cows.isEmpty && !bulls.isEmpty {
                animal.dam = cows.randomElement()
                animal.sire = bulls.randomElement()
            }

            sold.append(animal)
        }

        return sold
    }

    private func createDeceasedCattle(count: Int) -> [Cattle] {
        var deceased: [Cattle] = []

        for i in 1...count {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-D\(String(format: "%03d", i))"
            animal.sex = i % 2 == 0 ? CattleSex.heifer.rawValue : CattleSex.bull.rawValue
            animal.breed = angusBreed
            animal.cattleType = CattleType.beef.rawValue
            animal.color = "Black"
            animal.dateOfBirth = Calendar.current.date(byAdding: .month, value: -(12 + (i % 20)), to: Date())
            animal.currentStatus = CattleStatus.deceased.rawValue
            animal.currentStage = [LegacyCattleStage.calf, LegacyCattleStage.weanling, LegacyCattleStage.stocker, LegacyCattleStage.feeder, LegacyCattleStage.breeding].randomElement()!.rawValue
            animal.productionPath = i % 2 == 0 ? LegacyProductionPath.breeding.rawValue : LegacyProductionPath.beefFinishing.rawValue
            animal.currentWeight = NSDecimalNumber(decimal: Decimal(400 + (i * 100)))
            animal.exitDate = Calendar.current.date(byAdding: .day, value: -(60 + i * 10), to: Date())
            animal.exitReason = "Deceased"
            animal.createdAt = Date()
            animal.modifiedAt = Date()

            if !cows.isEmpty && !bulls.isEmpty {
                animal.dam = cows.randomElement()
                animal.sire = bulls.randomElement()
            }

            deceased.append(animal)
        }

        return deceased
    }

    // MARK: - Health Records

    private func addHealthRecords(to cattle: [Cattle], count: Int) {
        let recordTypes: [LegacyHealthRecordType] = [.checkup, .vaccination, .treatment, .injury, .illness]
        let conditions = [
            "Routine checkup - healthy",
            "Annual vaccination",
            "Foot rot treatment",
            "Respiratory infection",
            "Minor injury - healing well",
            "Parasite treatment",
            "Pink eye treatment",
            "Scours treatment"
        ]
        let medications = [
            "Ivermectin",
            "Penicillin",
            "LA-200",
            "Banamine",
            "Dexamethasone",
            "Draxxin"
        ]

        for _ in 1...count {
            guard let animal = cattle.randomElement() else { continue }

            let record = HealthRecord.create(for: animal, type: recordTypes.randomElement()!, in: context)
            record.date = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...180), to: Date())
            record.condition = conditions.randomElement()
            record.temperature = NSDecimalNumber(decimal: Decimal(100.0 + Double.random(in: 0...3)))

            if Bool.random() {
                record.medication = medications.randomElement()
                record.dosage = "\(Int.random(in: 5...20)) ml"
                record.administrationMethod = AdministrationMethod.injection.rawValue
            }

            if Bool.random() {
                record.veterinarian = ["Dr. Smith", "Dr. Johnson", "Dr. Williams"].randomElement()
                record.cost = NSDecimalNumber(decimal: Decimal(Double.random(in: 50...300)))
            }

            record.notes = "Treatment administered successfully. Animal responded well."
        }
    }

    // MARK: - Pregnancy Records

    private func addPregnancies(to cows: [Cattle], count: Int) {
        let statuses: [PregnancyStatus] = [.bred, .exposed, .confirmed, .confirmed, .open]
        let methods: [BreedingMethod] = [.natural, .natural, .natural, .artificialInsemination]

        for i in 0..<min(count, cows.count) {
            let cow = cows[i]
            let method = methods.randomElement()!
            let pregnancy = PregnancyRecord.create(for: cow, method: method, in: context)
            pregnancy.breedingDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 30...250), to: Date())

            if method == .natural {
                pregnancy.bull = bulls.randomElement()
            } else {
                pregnancy.externalBullName = ["Angus Ace", "Black Diamond", "Thunder King", "Profit Maker"].randomElement()
                pregnancy.externalBullRegistration = "ANG-\(Int.random(in: 100000...999999))"
            }

            pregnancy.status = statuses.randomElement()!.rawValue

            if pregnancy.status == PregnancyStatus.confirmed.rawValue {
                pregnancy.confirmedDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 10...80), to: Date())
                pregnancy.confirmationMethod = ["Ultrasound", "Palpation", "Blood Test"].randomElement()
            }

            // Calculate expected calving date (283 days from breeding)
            if let breedingDate = pregnancy.breedingDate {
                pregnancy.expectedCalvingDate = Calendar.current.date(byAdding: .day, value: 283, to: breedingDate)
            }

            pregnancy.notes = ["Cow in good condition, pregnancy progressing normally.", "Breeding successful, monitoring closely.", "First calf heifer, good health."].randomElement()
        }
    }

    // MARK: - Calving Records

    private func addCalvingRecords(to cows: [Cattle], calves: [Cattle], count: Int) {
        let difficulties: [CalvingEase] = [.unassisted, .unassisted, .unassisted, .unassisted, .easyPull, .hardPull]

        for i in 0..<min(count, cows.count, calves.count) {
            let cow = cows[i]
            let calf = calves[i]

            let calvingRecord = CalvingRecord.create(for: cow, in: context)
            calvingRecord.calvingDate = calf.dateOfBirth
            calvingRecord.dam = cow
            calvingRecord.sire = bulls.randomElement()
            calvingRecord.calf = calf
            calvingRecord.calfSex = calf.sex ?? ""
            calvingRecord.calfBirthWeight = NSDecimalNumber(decimal: Decimal(Double.random(in: 65...90)))
            calvingRecord.difficulty = difficulties.randomElement()!.rawValue
            // Note: calfStatus removed from CalvingRecord Core Data model

            if calvingRecord.difficulty == CalvingEase.easyPull.rawValue {
                calvingRecord.assistanceProvided = "Pulled calf, light assistance"
                calvingRecord.veterinarianCalled = Bool.random()
            } else if calvingRecord.difficulty == CalvingEase.hardPull.rawValue {
                calvingRecord.veterinarianCalled = true
                calvingRecord.assistanceProvided = "Difficult birth, veterinary assistance, administered oxytocin"
            }

            calvingRecord.notes = ["Healthy calf, cow recovering well.", "Normal calving, strong calf.", "First calf heifer, did well."].randomElement()
        }
    }

    // MARK: - Processing Records

    private func addProcessingRecords(to cattle: [Cattle]) {
        let processors = ["ABC Meat Processing", "Countryside Butcher", "Prime Cut Processing", "Valley Meat Co."]

        for animal in cattle {
            guard let processingDate = animal.processingDate else { continue }

            let record = ProcessingRecord.create(for: animal, in: context)
            record.processingDate = processingDate
            record.processor = processors.randomElement()

            // Generate realistic weights
            let liveWeight = Decimal(Double.random(in: 1050...1250))
            let dressPercent = Decimal(Double.random(in: 58...64))
            let hangingWeight = liveWeight * (dressPercent / 100)

            record.liveWeight = NSDecimalNumber(decimal: liveWeight)
            record.hangingWeight = NSDecimalNumber(decimal: hangingWeight)
            record.dressPercentage = NSDecimalNumber(decimal: dressPercent)
            record.processingCost = NSDecimalNumber(decimal: Decimal(Double.random(in: 400...650)))
            record.notes = "Standard processing, good yield."
        }
    }

    // MARK: - Sale Records

    private func addSaleRecords(to cattle: [Cattle]) {
        _ = ["Smith Ranch", "Johnson Cattle Co.", "Valley Farm", "Local Livestock Market", "Private Buyer"]
        _ = ["Private Sale", "Auction", "Direct Sale"]
        _ = ["Cash", "Check", "Bank Transfer"]

        for animal in cattle {
            guard let saleDate = animal.exitDate else { continue }

            let record = SaleRecord.create(for: animal, in: context)
            record.saleDate = saleDate
            // Note: buyer, buyerContact, marketType, paymentMethod removed from SaleRecord Core Data model
            // Database uses buyer_id UUID FK to contacts table

            if let weight = animal.currentWeight as? Decimal, weight > 0 {
                record.saleWeight = NSDecimalNumber(decimal: weight)
                let pricePerPound = Decimal(Double.random(in: 1.20...2.80))
                let salePrice = weight * pricePerPound
                record.salePrice = NSDecimalNumber(decimal: salePrice)
                record.pricePerPound = NSDecimalNumber(decimal: pricePerPound)
            } else {
                record.salePrice = NSDecimalNumber(decimal: Decimal(Double.random(in: 800...1600)))
            }

            record.notes = "Sale completed successfully."
        }
    }

    // MARK: - Mortality Records

    private func addMortalityRecords(to cattle: [Cattle]) {
        let causes = ["Illness", "Injury", "Unknown", "Calving complication", "Predator", "Natural causes"]
        let categories = ["Disease", "Injury", "Calving Complications", "Natural Causes", "Unknown"]
        let disposalMethods = ["Burial", "Rendering", "Composting"]

        for animal in cattle {
            guard let deathDate = animal.exitDate else { continue }

            let record = MortalityRecord.create(for: animal, in: context)
            record.deathDate = deathDate
            record.cause = causes.randomElement()
            let category = categories.randomElement()!
            record.causeCategory = category
            record.disposalMethod = disposalMethods.randomElement()

            if Bool.random() {
                record.veterinarian = ["Dr. Smith", "Dr. Johnson", "Dr. Williams"].randomElement()
                record.necropsyPerformed = Bool.random()

                if record.necropsyPerformed {
                    record.necropsyResults = "Results showed indication of \(record.cause ?? "unknown cause")"
                }
            }

            record.reportedToAuthorities = category == "Disease" && Bool.random()
            record.notes = "Event recorded and documented."
        }
    }
}
