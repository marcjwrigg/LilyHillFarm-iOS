//
//  Medication+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension Medication {

    // MARK: - Computed Properties

    var displayValue: String {
        name ?? "Unknown Medication"
    }

    var typeDisplay: String {
        medicationType ?? "General"
    }

    // MARK: - Factory Methods

    static func create(from dto: MedicationDTO, in context: NSManagedObjectContext) -> Medication {
        let medication = Medication(context: context)
        dto.update(medication)
        return medication
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        return true
    }
}

// MARK: - DTO Extension

extension MedicationDTO {
    func update(_ entity: Medication) {
        entity.id = self.id
        entity.userId = self.userId
        entity.farmId = self.farmId
        entity.name = self.name
        entity.medicationType = self.type
        entity.manufacturer = self.manufacturer
        entity.commonDosage = self.commonDosage
        entity.withdrawalPeriod = self.withdrawalPeriod
        entity.notes = self.notes
        entity.isActive = self.isActive ?? true

        // Parse dates
        if let createdAt = self.createdAt {
            entity.createdAt = ISO8601DateFormatter().date(from: createdAt)
        }
        if let modifiedAt = self.modifiedAt {
            entity.modifiedAt = ISO8601DateFormatter().date(from: modifiedAt)
        }
        if let updatedAt = self.updatedAt {
            entity.updatedAt = ISO8601DateFormatter().date(from: updatedAt)
        }

        entity.syncStatus = "synced"
    }
}
