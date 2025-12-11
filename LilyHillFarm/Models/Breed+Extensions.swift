//
//  Breed+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension Breed {

    // MARK: - Computed Properties

    var displayName: String {
        name ?? "Unknown Breed"
    }

    var cattleArray: [Cattle] {
        let cattleSet = cattle as? Set<Cattle> ?? []
        return Array(cattleSet).sorted { $0.tagNumber ?? "" < $1.tagNumber ?? "" }
    }

    var activeCattleCount: Int {
        cattleArray.filter { $0.currentStatus == CattleStatus.active.rawValue }.count
    }

    // MARK: - Factory Methods

    static func create(name: String, category: BreedCategory, in context: NSManagedObjectContext) -> Breed {
        let breed = Breed(context: context)
        breed.id = UUID()
        breed.name = name
        breed.category = category.rawValue
        breed.isActive = true
        return breed
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        guard let category = category, !category.isEmpty else { return false }
        return true
    }
}
