//
//  Buyer+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension Buyer {

    // MARK: - Computed Properties

    var displayValue: String {
        name ?? "Unknown Buyer"
    }

    var typeDisplay: String {
        buyerType ?? "Individual"
    }

    var fullDisplayName: String {
        if let type = buyerType, !type.isEmpty, type != "Individual" {
            return "\(name ?? "Unknown") (\(type))"
        }
        return displayValue
    }

    // MARK: - Factory Methods

    static func create(from dto: BuyerDTO, in context: NSManagedObjectContext) -> Buyer {
        let buyer = Buyer(context: context)
        dto.update(buyer)
        return buyer
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        return true
    }
}

// MARK: - DTO Extension

extension BuyerDTO {
    func update(_ entity: Buyer) {
        entity.id = self.id
        entity.name = self.name
        entity.buyerType = self.type
        entity.contactName = self.contactName
        entity.phone = self.phone
        entity.email = self.email
        entity.address = self.address
        entity.city = self.city
        entity.state = self.state
        entity.zipCode = self.zipCode
        entity.notes = self.notes
        entity.isActive = self.isActive ?? true

        // Parse dates
        if let createdAt = self.createdAt {
            entity.createdAt = ISO8601DateFormatter().date(from: createdAt)
        }
        if let updatedAt = self.updatedAt {
            entity.updatedAt = ISO8601DateFormatter().date(from: updatedAt)
        }

        entity.syncStatus = "synced"
    }
}
