//
//  DataTypes.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation

// MARK: - Cattle Enums

enum CattleSex: String, CaseIterable, Identifiable {
    case bull = "Bull"
    case cow = "Cow"
    case steer = "Steer"
    case heifer = "Heifer"

    var id: String { rawValue }
}

enum CattleType: String, CaseIterable, Identifiable {
    case beef = "Beef"
    case dairy = "Dairy"

    var id: String { rawValue }
}

enum CattleStatus: String, CaseIterable, Identifiable {
    case active = "Active"
    case sold = "Sold"
    case processed = "Processed"
    case deceased = "Deceased"

    var id: String { rawValue }
}

enum CattleStage: String, CaseIterable, Identifiable {
    case calf = "Calf"
    case weanling = "Weanling"
    case stocker = "Stocker"
    case feeder = "Feeder"
    case breeding = "Breeding"
    case processed = "Processed"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var shortName: String {
        switch self {
        case .calf: return "Calves"
        case .weanling: return "Weanling"
        case .stocker: return "Stocker"
        case .feeder: return "Feeder"
        case .breeding: return "Breeding"
        case .processed: return "Processed"
        }
    }
}

enum ProductionPath: String, CaseIterable, Identifiable {
    case beefFinishing = "BeefFinishing"
    case breeding = "Breeding"
    case dairy = "Dairy"
    case market = "Market"
    case replacement = "Replacement"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beefFinishing: return "Beef Finishing"
        case .breeding: return "Breeding"
        case .dairy: return "Dairy"
        case .market: return "Market"
        case .replacement: return "Replacement"
        }
    }
}

// MARK: - Breed Enums

enum BreedCategory: String, CaseIterable, Identifiable {
    case beef = "Beef"
    case dairy = "Dairy"
    case dual = "Dual Purpose"

    var id: String { rawValue }
}

// MARK: - Health Record Enums

enum HealthRecordType: String, CaseIterable, Identifiable {
    case illness = "Illness"
    case treatment = "Treatment"
    case vaccination = "Vaccination"
    case checkup = "Checkup"
    case injury = "Injury"
    case surgery = "Surgery"
    case dental = "Dental"
    case other = "Other"

    var id: String { rawValue }
}

enum AdministrationMethod: String, CaseIterable, Identifiable {
    case oral = "Oral"
    case injection = "Injection"
    case topical = "Topical"
    case intravenous = "Intravenous"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - Calving Record Enums

enum CalvingEase: String, CaseIterable, Identifiable {
    case unassisted = "Unassisted"
    case easyPull = "Easy Pull"
    case hardPull = "Hard Pull"
    case caesarean = "Caesarean"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }
}

enum CalfStatus: String, CaseIterable, Identifiable {
    case alive = "Alive"
    case stillborn = "Stillborn"
    case diedAfterBirth = "Died After Birth"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alive: return "Alive"
        case .stillborn: return "Stillborn"
        case .diedAfterBirth: return "Died After Birth"
        }
    }
}

// MARK: - Pregnancy Record Enums

enum BreedingMethod: String, CaseIterable, Identifiable {
    case natural = "Natural"
    case artificialInsemination = "AI"
    case embryoTransfer = "Embryo Transfer"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .artificialInsemination: return "Artificial Insemination"
        case .embryoTransfer: return "Embryo Transfer"
        }
    }
}

enum PregnancyStatus: String, CaseIterable, Identifiable {
    case pending = "pending"
    case open = "open"
    case bred = "bred"
    case exposed = "exposed"
    case confirmed = "confirmed"
    case calved = "calved"
    case lost = "lost"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .open: return "Open"
        case .bred: return "Bred"
        case .exposed: return "Exposed"
        case .confirmed: return "Confirmed"
        case .calved: return "Calved"
        case .lost: return "Lost"
        }
    }
}

enum PregnancyConfirmationMethod: String, CaseIterable, Identifiable {
    case palpation = "Palpation"
    case ultrasound = "Ultrasound"
    case bloodTest = "Blood Test"
    case visual = "Visual"

    var id: String { rawValue }
}

// MARK: - Common Weight Units

enum WeightUnit: String, CaseIterable {
    case pounds = "lbs"
    case kilograms = "kg"

    func convert(_ value: Decimal, to unit: WeightUnit) -> Decimal {
        if self == unit { return value }

        switch (self, unit) {
        case (.pounds, .kilograms):
            return value * Decimal(0.453592)
        case (.kilograms, .pounds):
            return value * Decimal(2.20462)
        default:
            return value
        }
    }
}

// MARK: - Helper Structs

struct StagePromotionInfo {
    let fromStage: CattleStage
    let toStage: CattleStage
    let recommendedMinimumWeightLbs: Decimal?
    let typicalAgeMonths: Int?

    // Beef Finishing Path
    static let calfToWeanling = StagePromotionInfo(
        fromStage: .calf,
        toStage: .weanling,
        recommendedMinimumWeightLbs: 400,
        typicalAgeMonths: 6
    )

    static let weanlingToStocker = StagePromotionInfo(
        fromStage: .weanling,
        toStage: .stocker,
        recommendedMinimumWeightLbs: 500,
        typicalAgeMonths: 8
    )

    static let stockerToFeeder = StagePromotionInfo(
        fromStage: .stocker,
        toStage: .feeder,
        recommendedMinimumWeightLbs: 700,
        typicalAgeMonths: 12
    )

    static let feederToProcessed = StagePromotionInfo(
        fromStage: .feeder,
        toStage: .processed,
        recommendedMinimumWeightLbs: 1200,
        typicalAgeMonths: 18
    )

    // Breeding Path
    static let weanlingToBreeding = StagePromotionInfo(
        fromStage: .weanling,
        toStage: .breeding,
        recommendedMinimumWeightLbs: 650,
        typicalAgeMonths: 12
    )

    static let stockerToBreeding = StagePromotionInfo(
        fromStage: .stocker,
        toStage: .breeding,
        recommendedMinimumWeightLbs: 750,
        typicalAgeMonths: 14
    )

    static let breedingToProcessed = StagePromotionInfo(
        fromStage: .breeding,
        toStage: .processed,
        recommendedMinimumWeightLbs: 1000,
        typicalAgeMonths: 24
    )
}

// MARK: - Validation Helpers

struct CattleValidation {
    static func isValidTagNumber(_ tagNumber: String) -> Bool {
        // Basic validation - can be customized based on your tagging system
        !tagNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func isValidWeight(_ weight: Decimal) -> Bool {
        weight > 0 && weight < 5000 // Reasonable range for cattle
    }

    static func isValidTemperature(_ temp: Decimal) -> Bool {
        temp >= 95 && temp <= 110 // Normal range for cattle in Fahrenheit
    }

    static func gestationPeriod(from breedingDate: Date) -> Date {
        // Average cattle gestation is 283 days
        Calendar.current.date(byAdding: .day, value: 283, to: breedingDate) ?? breedingDate
    }

    static func estimatedWeaningAge(from birthDate: Date) -> Date {
        // Typical weaning at 6-8 months
        Calendar.current.date(byAdding: .month, value: 7, to: birthDate) ?? birthDate
    }
}

// MARK: - Breed Common Data

struct CommonBreeds {
    static let beefBreeds = [
        "Angus",
        "Hereford",
        "Charolais",
        "Simmental",
        "Limousin",
        "Gelbvieh",
        "Red Angus",
        "Shorthorn",
        "Texas Longhorn",
        "Brahman",
        "Brangus",
        "Beefmaster",
        "Santa Gertrudis",
        "Murray Grey",
        "Piedmontese",
        "Wagyu"
    ]

    static let dairyBreeds = [
        "Holstein",
        "Jersey",
        "Guernsey",
        "Ayrshire",
        "Brown Swiss",
        "Milking Shorthorn"
    ]

    static let dualPurposeBreeds = [
        "Dexter",
        "Normande",
        "Montbéliarde"
    ]
}
