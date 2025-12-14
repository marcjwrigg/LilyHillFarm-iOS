//
//  TreatmentPlan+Extensions.swift
//  LilyHillFarm
//
//  Created by Claude Code on 12/11/25.
//

import Foundation
internal import CoreData

extension TreatmentPlan {

    // MARK: - Computed Properties

    var displayValue: String {
        name ?? "Unknown Treatment Plan"
    }

    var conditionDisplay: String {
        condition ?? "General"
    }

    // MARK: - Factory Methods

    static func create(from dto: TreatmentPlanDTO, in context: NSManagedObjectContext) -> TreatmentPlan {
        let plan = TreatmentPlan(context: context)
        dto.update(plan)
        return plan
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let name = name, !name.isEmpty else { return false }
        return true
    }
}
