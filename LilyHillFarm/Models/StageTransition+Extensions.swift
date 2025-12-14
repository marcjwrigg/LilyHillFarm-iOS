//
//  StageTransition+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension StageTransition {

    // MARK: - Computed Properties

    var displayDate: String {
        guard let date = transitionDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var displayFromStage: String {
        fromStage ?? "Birth"
    }

    var displayToStage: String {
        toStage ?? "Unknown"
    }

    var displayWeight: String? {
        guard let weight = weight as? Decimal, weight > 0 else { return nil }
        return "\(weight) lbs"
    }

    var daysSinceTransition: Int {
        guard let date = transitionDate else { return 0 }
        let components = Calendar.current.dateComponents([.day], from: date, to: Date())
        return components.day ?? 0
    }

    // MARK: - Factory Methods

    static func create(for cattle: Cattle, toStage: LegacyCattleStage, in context: NSManagedObjectContext) -> StageTransition {
        let transition = StageTransition(context: context)
        transition.id = UUID()
        transition.cattle = cattle
        transition.fromStage = cattle.currentStage
        transition.toStage = toStage.rawValue
        transition.transitionDate = Date()
        transition.createdAt = Date()
        return transition
    }
}
