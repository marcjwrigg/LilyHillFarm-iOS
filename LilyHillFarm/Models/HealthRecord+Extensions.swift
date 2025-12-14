//
//  HealthRecord+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension HealthRecord {

    // MARK: - Computed Properties

    var sortedPhotos: [Photo] {
        let photoArray = photos?.allObjects as? [Photo] ?? []
        return photoArray.sorted { ($0.dateTaken ?? Date.distantPast) > ($1.dateTaken ?? Date.distantPast) }
    }

    var isFollowUpNeeded: Bool {
        guard let followUpDate = followUpDate else { return false }
        return !followUpCompleted && followUpDate >= Date()
    }

    var isFollowUpOverdue: Bool {
        guard let followUpDate = followUpDate else { return false }
        return !followUpCompleted && followUpDate < Date()
    }

    var daysUntilFollowUp: Int? {
        guard let followUpDate = followUpDate, !followUpCompleted else { return nil }
        let components = Calendar.current.dateComponents([.day], from: Date(), to: followUpDate)
        return components.day
    }

    var daysSinceRecord: Int {
        guard let date = date else { return 0 }
        let components = Calendar.current.dateComponents([.day], from: date, to: Date())
        return components.day ?? 0
    }

    var displayType: String {
        recordType ?? "Unknown"
    }

    var displayTypeWithCondition: String {
        let type = recordType ?? "Unknown"
        if let condition = condition, !condition.isEmpty {
            return "\(type) - \(condition)"
        }
        return type
    }

    var typeIcon: String {
        guard let type = LegacyHealthRecordType(rawValue: recordType ?? "") else {
            return "heart.text.square"
        }

        switch type {
        case .illness: return "cross.case"
        case .treatment: return "pills"
        case .vaccination: return "syringe"
        case .checkup: return "stethoscope"
        case .injury: return "bandage"
        case .surgery: return "bandage.fill"
        case .dental: return "mouth"
        case .other: return "heart.text.square"
        }
    }

    var displayDate: String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Factory Methods

    static func create(for cattle: Cattle, type: LegacyHealthRecordType, in context: NSManagedObjectContext) -> HealthRecord {
        let record = HealthRecord(context: context)
        record.id = UUID()
        record.cattle = cattle
        record.recordType = type.rawValue
        record.date = Date()
        record.followUpCompleted = false
        record.createdAt = Date()
        return record
    }

    // MARK: - Validation

    var isValid: Bool {
        guard recordType != nil else { return false }
        return true
    }
}
