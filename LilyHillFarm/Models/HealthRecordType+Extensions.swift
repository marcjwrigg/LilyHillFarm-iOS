//
//  HealthRecordType+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension HealthRecordType {

    // MARK: - Computed Properties

    var displayValue: String {
        name ?? "Unknown Type"
    }

    // MARK: - Factory Methods

    static func create(from dto: HealthRecordTypeDTO, in context: NSManagedObjectContext) -> HealthRecordType {
        let type = HealthRecordType(context: context)
        dto.update(type)
        return type
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        return true
    }
}

// MARK: - DTO Extension

extension HealthRecordTypeDTO {
    func update(_ entity: HealthRecordType) {
        entity.id = self.id
        entity.name = self.name
        entity.typeDescription = self.description
        entity.icon = self.icon
        entity.color = self.color
        entity.isActive = self.isActive ?? true
        entity.farmId = self.farmId

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
