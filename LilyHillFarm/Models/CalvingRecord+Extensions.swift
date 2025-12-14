//
//  CalvingRecord+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension CalvingRecord {

    // MARK: - Computed Properties

    var sortedPhotos: [Photo] {
        let photoArray = photos?.allObjects as? [Photo] ?? []
        return photoArray.sorted { ($0.dateTaken ?? Date.distantPast) > ($1.dateTaken ?? Date.distantPast) }
    }

    var displayDate: String {
        guard let date = calvingDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var displayDifficulty: String {
        difficulty ?? "Unknown"
    }

    var calfDisplayName: String {
        if let calf = calf {
            return calf.displayName
        }
        return "Calf (\(calfSex ?? "Unknown"))"
    }

    // Note: calfWeightAtWeaning removed from CalvingRecord Core Data model
    var weightGainFromBirthToWeaning: Decimal? {
        return nil  // Field removed, can't calculate
    }

    // Note: calfStatus removed from CalvingRecord Core Data model
    var isSuccessful: Bool {
        return calf != nil  // Consider successful if calf record exists
    }

    var requiresAttention: Bool {
        // Requires attention if difficult calving or complications
        return difficulty == CalvingEase.hardPull.rawValue ||
               difficulty == CalvingEase.caesarean.rawValue ||
               complications != nil && !(complications?.isEmpty ?? true)
    }

    // MARK: - Factory Methods

    static func create(for dam: Cattle, in context: NSManagedObjectContext) -> CalvingRecord {
        let record = CalvingRecord(context: context)
        record.id = UUID()
        record.dam = dam
        record.calvingDate = Date()
        record.difficulty = CalvingEase.unassisted.rawValue
        // Note: calfStatus removed from CalvingRecord Core Data model
        record.veterinarianCalled = false
        record.createdAt = Date()
        return record
    }

    // MARK: - Calf Creation

    func createCalfRecord(tagNumber: String, name: String?, breed: Breed?, in context: NSManagedObjectContext) -> Cattle {
        let calf = Cattle.create(in: context)
        calf.tagNumber = tagNumber
        calf.name = name
        calf.breed = breed ?? dam?.breed
        calf.sex = calfSex ?? ""
        calf.dateOfBirth = calvingDate
        calf.currentStage = LegacyCattleStage.calf.rawValue
        calf.productionPath = LegacyProductionPath.beefFinishing.rawValue
        calf.dam = dam
        calf.sire = sire

        if let birthWeight = calfBirthWeight {
            calf.currentWeight = birthWeight
        }

        self.calf = calf

        return calf
    }

    // MARK: - Validation

    var isValid: Bool {
        guard dam != nil else { return false }
        guard difficulty != nil else { return false }
        guard calfSex != nil else { return false }
        return true
    }
}
