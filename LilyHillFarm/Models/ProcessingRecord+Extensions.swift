//
//  ProcessingRecord+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension ProcessingRecord {

    // MARK: - Computed Properties

    var dressPercentageCalculated: Decimal? {
        guard let live = liveWeight as? Decimal,
              let hanging = hangingWeight as? Decimal,
              live > 0 else {
            return nil
        }
        return (hanging / live) * 100
    }

    var processorDisplayName: String {
        processor ?? "Unknown Processor"
    }

    var sortedPhotos: [Photo] {
        let photoArray = photos?.allObjects as? [Photo] ?? []
        return photoArray.sorted { ($0.dateTaken ?? Date.distantPast) > ($1.dateTaken ?? Date.distantPast) }
    }

    // MARK: - Factory Methods

    static func create(for cattle: Cattle, in context: NSManagedObjectContext) -> ProcessingRecord {
        let record = ProcessingRecord(context: context)
        record.id = UUID()
        record.cattle = cattle
        record.processingDate = Date()
        record.createdAt = Date()
        return record
    }
}
