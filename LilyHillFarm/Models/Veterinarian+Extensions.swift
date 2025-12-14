//
//  Veterinarian+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension Veterinarian {

    // MARK: - Computed Properties

    var displayValue: String {
        name ?? "Unknown Veterinarian"
    }

    var fullDisplayName: String {
        if let clinic = clinicName, !clinic.isEmpty {
            return "\(name ?? "Unknown") - \(clinic)"
        }
        return displayValue
    }

    // MARK: - Factory Methods

    static func create(from dto: VeterinarianDTO, in context: NSManagedObjectContext) -> Veterinarian {
        let vet = Veterinarian(context: context)
        dto.update(vet)
        return vet
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        return true
    }
}

// MARK: - DTO Extension

extension VeterinarianDTO {
    func update(_ entity: Veterinarian) {
        entity.id = self.id
        entity.farmId = self.farmId
        entity.name = self.name
        entity.clinicName = self.clinicName
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
