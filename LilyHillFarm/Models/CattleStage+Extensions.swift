//
//  CattleStage+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension CattleStage {

    // MARK: - Computed Properties

    var displayValue: String {
        displayName ?? name ?? "Unknown Stage"
    }

    // MARK: - Factory Methods

    static func create(from dto: CattleStageDTO, in context: NSManagedObjectContext) -> CattleStage {
        let stage = CattleStage(context: context)
        dto.update(stage)
        return stage
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        guard let displayName = displayName, !displayName.isEmpty else { return false }
        return true
    }
}

// MARK: - DTO Extension

extension CattleStageDTO {
    func update(_ entity: CattleStage) {
        entity.id = self.id
        entity.farmId = self.farmId
        entity.name = self.name
        entity.displayName = self.displayName
        entity.stageDescription = self.description
        entity.color = self.color
        entity.icon = self.icon
        entity.sortOrder = Int32(self.sortOrder)
        entity.isSystem = self.isSystem ?? false
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
