//
//  MortalityRecord+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension MortalityRecord {

    // MARK: - Computed Properties

    var sortedPhotos: [Photo] {
        let photoArray = photos?.allObjects as? [Photo] ?? []
        return photoArray.sorted { ($0.dateTaken ?? Date.distantPast) > ($1.dateTaken ?? Date.distantPast) }
    }

    // MARK: - Factory Methods

    static func create(for cattle: Cattle, in context: NSManagedObjectContext) -> MortalityRecord {
        let record = MortalityRecord(context: context)
        record.id = UUID()
        record.cattle = cattle
        record.deathDate = Date()
        record.createdAt = Date()
        return record
    }
}
