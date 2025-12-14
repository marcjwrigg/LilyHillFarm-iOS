//
//  Pasture+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension Pasture {

    // MARK: - Computed Properties

    var displayValue: String {
        name ?? "Unknown Pasture"
    }

    var typeDisplay: String {
        pastureType ?? "Unknown"
    }

    var conditionDisplay: String {
        pastureCondition ?? "Unknown"
    }

    var occupancyDisplay: String {
        if carryingCapacity > 0 {
            return "\(currentOccupancy)/\(carryingCapacity) head"
        }
        return "\(currentOccupancy) head"
    }

    var hasMap: Bool {
        return boundaryCoordinates != nil || (centerLat != 0 && centerLng != 0)
    }

    // MARK: - Factory Methods

    static func create(from dto: PastureDTO, in context: NSManagedObjectContext) -> Pasture {
        let pasture = Pasture(context: context)
        dto.update(pasture)
        return pasture
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        guard let type = pastureType, !type.isEmpty else { return false }
        guard let condition = pastureCondition, !condition.isEmpty else { return false }
        return true
    }
}

// MARK: - DTO Extension

extension PastureDTO {
    func update(_ entity: Pasture) {
        entity.id = self.id
        entity.userId = self.userId
        entity.farmId = self.farmId
        entity.name = self.name
        entity.pastureType = self.pastureType
        entity.acreage = self.acreage ?? 0
        entity.fencingType = self.fencingType
        entity.waterSource = self.waterSource
        entity.carryingCapacity = Int32(self.carryingCapacity ?? 0)
        entity.currentOccupancy = Int32(self.currentOccupancy ?? 0)
        entity.pastureCondition = self.condition
        entity.restPeriodDays = Int32(self.restPeriodDays ?? 0)
        entity.forageType = self.forageType
        entity.forageAcres = self.forageAcres ?? 0
        entity.notes = self.notes
        entity.boundaryCoordinates = self.boundaryCoordinates
        entity.forageBoundaryCoordinates = self.forageBoundaryCoordinates
        entity.centerLat = self.centerLat ?? 0
        entity.centerLng = self.centerLng ?? 0
        entity.mapZoomLevel = Int32(self.mapZoomLevel ?? 0)

        // Parse dates
        if let lastGrazed = self.lastGrazedDate {
            entity.lastGrazedDate = ISO8601DateFormatter().date(from: lastGrazed)
        }
        if let createdAt = self.createdAt {
            entity.createdAt = ISO8601DateFormatter().date(from: createdAt)
        }
        if let updatedAt = self.updatedAt {
            entity.updatedAt = ISO8601DateFormatter().date(from: updatedAt)
        }
        if let deletedAt = self.deletedAt {
            entity.deletedAt = ISO8601DateFormatter().date(from: deletedAt)
        }

        entity.syncStatus = "synced"
    }
}
