//
//  ProductionPathStage+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension ProductionPathStage {

    // MARK: - Computed Properties

    var displayValue: String {
        "Stage \(stageOrder + 1)"
    }

    // MARK: - Factory Methods

    static func create(from dto: ProductionPathStageDTO, in context: NSManagedObjectContext) -> ProductionPathStage {
        let stage = ProductionPathStage(context: context)
        dto.update(stage)
        return stage
    }

    // MARK: - Validation

    var isValid: Bool {
        return productionPathId != nil && stageId != nil
    }
}

// MARK: - DTO Extension

extension ProductionPathStageDTO {
    func update(_ entity: ProductionPathStage) {
        entity.id = self.id
        entity.farmId = self.farmId
        entity.productionPathId = self.productionPathId
        entity.stageId = self.stageId
        entity.stageOrder = Int32(self.stageOrder)
        entity.isOptional = self.isOptional ?? false
        if let minDays = self.minDays {
            entity.minDays = Int32(minDays)
        }
        if let maxDays = self.maxDays {
            entity.maxDays = Int32(maxDays)
        }
        if let targetWeightMin = self.targetWeightMin {
            entity.targetWeightMin = NSDecimalNumber(decimal: Decimal(targetWeightMin))
        }
        if let targetWeightMax = self.targetWeightMax {
            entity.targetWeightMax = NSDecimalNumber(decimal: Decimal(targetWeightMax))
        }
        entity.notes = self.notes

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
