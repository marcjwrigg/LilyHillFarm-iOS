//
//  SeedDataService.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

class SeedDataService {

    static let shared = SeedDataService()

    private let userDefaultsKey = "HasSeededData"

    private init() {}

    // MARK: - Main Seed Method

    func seedDataIfNeeded(in context: NSManagedObjectContext) {
        let hasSeeded = UserDefaults.standard.bool(forKey: userDefaultsKey)

        guard !hasSeeded else {
            print("ℹ️ Data already seeded, skipping...")
            return
        }

        print("🌱 Seeding initial data...")

        seedBreeds(in: context)

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            print("✅ Seed data saved successfully")
        } catch {
            print("❌ Error saving seed data: \(error)")
        }
    }

    // MARK: - Breed Seeding

    private func seedBreeds(in context: NSManagedObjectContext) {
        print("📝 Seeding breeds...")

        // Seed Beef Breeds
        for breedName in CommonBreeds.beefBreeds {
            let breed = Breed.create(name: breedName, category: .beef, in: context)
            breed.characteristics = getBreedCharacteristics(for: breedName)
        }

        // Seed Dairy Breeds
        for breedName in CommonBreeds.dairyBreeds {
            let breed = Breed.create(name: breedName, category: .dairy, in: context)
            breed.characteristics = getBreedCharacteristics(for: breedName)
        }

        // Seed Dual Purpose Breeds
        for breedName in CommonBreeds.dualPurposeBreeds {
            let breed = Breed.create(name: breedName, category: .dual, in: context)
            breed.characteristics = getBreedCharacteristics(for: breedName)
        }

        print("✅ Seeded \(CommonBreeds.beefBreeds.count + CommonBreeds.dairyBreeds.count + CommonBreeds.dualPurposeBreeds.count) breeds")
    }

    // MARK: - Breed Characteristics

    private func getBreedCharacteristics(for breedName: String) -> String {
        switch breedName {
        // Beef Breeds
        case "Angus":
            return "Excellent marbling, docile temperament, maternal qualities"
        case "Hereford":
            return "Hardy, adaptable, good foragers, excellent beef quality"
        case "Charolais":
            return "Large frame, lean muscle, excellent growth rate"
        case "Simmental":
            return "Versatile, good milk production, rapid growth"
        case "Limousin":
            return "Lean meat, efficient feed conversion, easy calving"
        case "Gelbvieh":
            return "Maternal ability, growth rate, carcass quality"
        case "Red Angus":
            return "Heat tolerance, marbling, maternal traits"
        case "Shorthorn":
            return "Docile, adaptable, dual-purpose capabilities"
        case "Texas Longhorn":
            return "Hardy, disease resistant, low maintenance"
        case "Brahman":
            return "Heat tolerant, disease resistant, longevity"
        case "Brangus":
            return "Heat tolerance, hardiness, quality beef"
        case "Beefmaster":
            return "Fertility, milk production, adaptability"
        case "Santa Gertrudis":
            return "Heat tolerance, foraging ability, good disposition"
        case "Murray Grey":
            return "Easy calving, docile, quality beef"
        case "Piedmontese":
            return "Double muscling, lean meat, tender beef"
        case "Wagyu":
            return "Exceptional marbling, high quality beef, docile"

        // Dairy Breeds
        case "Holstein":
            return "High milk production, large frame, efficient"
        case "Jersey":
            return "High butterfat, docile, heat tolerant"
        case "Guernsey":
            return "Golden milk, docile, efficient grazer"
        case "Ayrshire":
            return "Hardy, adaptable, moderate milk production"
        case "Brown Swiss":
            return "Longevity, docile, versatile"
        case "Milking Shorthorn":
            return "Dual purpose, docile, adaptable"

        // Dual Purpose
        case "Dexter":
            return "Small frame, efficient, dual purpose"
        case "Normande":
            return "Moderate size, milk and beef production"
        case "Montbéliarde":
            return "Hardy, milk quality, meat quality"

        default:
            return "Quality cattle breed"
        }
    }

    // MARK: - Reset Seed (For Development)

    func resetSeedData() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("🔄 Seed data reset. Will re-seed on next app launch.")
    }

    // MARK: - Check if Seeded

    func hasSeededData() -> Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
}
