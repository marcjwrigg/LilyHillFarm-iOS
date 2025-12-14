//
//  ProductionPath+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension ProductionPath {

    // MARK: - Computed Properties

    var displayValue: String {
        displayName ?? name ?? "Unknown Path"
    }

    var stagesArray: [ProductionPathStage] {
        let stagesSet = stages as? Set<ProductionPathStage> ?? []
        return Array(stagesSet).sorted { $0.stageOrder < $1.stageOrder }
    }

    // MARK: - Factory Methods

    static func create(from dto: ProductionPathDTO, in context: NSManagedObjectContext) -> ProductionPath {
        let path = ProductionPath(context: context)
        dto.update(path)
        return path
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        guard let displayName = displayName, !displayName.isEmpty else { return false }
        return true
    }
}

// MARK: - DTO Extension

extension ProductionPathDTO {
    func update(_ entity: ProductionPath) {
        entity.id = self.id
        entity.farmId = self.farmId
        entity.name = self.name
        entity.displayName = self.displayName
        entity.pathDescription = self.description
        entity.color = self.color
        entity.icon = self.icon
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
