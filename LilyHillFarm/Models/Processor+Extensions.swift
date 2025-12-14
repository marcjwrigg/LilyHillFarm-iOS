//
//  Processor+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension Processor {

    // MARK: - Computed Properties

    var displayValue: String {
        name ?? "Unknown Processor"
    }

    var fullDisplayName: String {
        if let loc = location, !loc.isEmpty {
            return "\(name ?? "Unknown") - \(loc)"
        }
        return displayValue
    }

    // MARK: - Factory Methods

    static func create(from dto: ProcessorDTO, in context: NSManagedObjectContext) -> Processor {
        let processor = Processor(context: context)
        dto.update(processor)
        return processor
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        return true
    }
}

// MARK: - DTO Extension

extension ProcessorDTO {
    func update(_ entity: Processor) {
        entity.id = self.id
        entity.farmId = self.farmId
        entity.name = self.name
        entity.location = self.location
        entity.phone = self.phone
        entity.email = self.email
        entity.notes = self.notes
        entity.isActive = true

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
