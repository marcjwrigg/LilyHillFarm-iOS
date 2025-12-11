//
//  SaleRecord+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension SaleRecord {

    // MARK: - Computed Properties

    var pricePerPoundCalculated: Decimal? {
        guard let price = salePrice as? Decimal,
              let weight = saleWeight as? Decimal,
              weight > 0 else {
            return nil
        }
        return price / weight
    }

    // Note: buyer and buyerContact fields removed from SaleRecord Core Data model
    // Database uses buyer_id UUID FK to contacts table, but iOS doesn't store buyer info
    var buyerDisplayName: String {
        "Unknown Buyer"  // TODO: Add buyer relationship to Contact entity if needed
    }

    var sortedPhotos: [Photo] {
        let photoArray = photos?.allObjects as? [Photo] ?? []
        return photoArray.sorted { ($0.dateTaken ?? Date.distantPast) > ($1.dateTaken ?? Date.distantPast) }
    }

    // MARK: - Factory Methods

    static func create(for cattle: Cattle, in context: NSManagedObjectContext) -> SaleRecord {
        let record = SaleRecord(context: context)
        record.id = UUID()
        record.cattle = cattle
        record.saleDate = Date()
        record.createdAt = Date()
        return record
    }
}
