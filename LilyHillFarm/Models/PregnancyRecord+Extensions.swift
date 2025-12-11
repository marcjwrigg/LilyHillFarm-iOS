//
//  PregnancyRecord+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension PregnancyRecord {

    // MARK: - Computed Properties

    var sortedPhotos: [Photo] {
        let photoArray = photos?.allObjects as? [Photo] ?? []
        return photoArray.sorted { ($0.dateTaken ?? Date.distantPast) > ($1.dateTaken ?? Date.distantPast) }
    }

    var displayBreedingDate: String {
        guard let date = breedingDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var displayExpectedCalvingDate: String? {
        guard let date = expectedCalvingDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var daysUntilCalving: Int? {
        // Use start of calving window if available, otherwise use single due date
        let referenceDate: Date?
        if let calvingStart = expectedCalvingStartDate {
            referenceDate = calvingStart
        } else {
            referenceDate = expectedCalvingDate
        }

        guard let date = referenceDate else { return nil }
        let components = Calendar.current.dateComponents([.day], from: Date(), to: date)
        return components.day
    }

    var daysUntilDue: Int? {
        daysUntilCalving
    }

    var displayDueDate: String {
        guard let date = expectedCalvingDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var displayConfirmationDate: String {
        guard let date = confirmedDate else { return "Not confirmed" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var displayMethod: String {
        guard let method = BreedingMethod(rawValue: breedingMethod ?? "") else {
            return "Unknown"
        }
        return method.displayName
    }

    var daysSinceBreeding: Int {
        guard let date = breedingDate else { return 0 }
        let components = Calendar.current.dateComponents([.day], from: date, to: Date())
        return components.day ?? 0
    }

    var gestationDays: Int? {
        daysSinceBreeding
    }

    var isOverdue: Bool {
        // Check if calving window end date has passed, or single due date has passed
        let referenceDate: Date?
        if let calvingEnd = expectedCalvingEndDate {
            referenceDate = calvingEnd
        } else {
            referenceDate = expectedCalvingDate
        }

        guard let date = referenceDate else { return false }
        return Date() > date && status != PregnancyStatus.calved.rawValue
    }

    var isDue: Bool {
        // Check if within 7 days of calving window start or single due date
        let referenceDate: Date?
        if let calvingStart = expectedCalvingStartDate {
            referenceDate = calvingStart
        } else {
            referenceDate = expectedCalvingDate
        }

        guard let date = referenceDate else { return false }
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return daysUntil <= 7 && daysUntil >= 0
    }

    var displayStatus: String {
        status ?? "Unknown"
    }

    var isActive: Bool {
        status == PregnancyStatus.confirmed.rawValue || status == PregnancyStatus.bred.rawValue || status == PregnancyStatus.exposed.rawValue
    }

    // MARK: - Gestation Tracking

    var gestationProgress: Double {
        // Average cattle gestation is 283 days
        let averageGestationDays = 283.0
        let currentGestationDays = Double(gestationDays ?? 0)
        return min(currentGestationDays / averageGestationDays, 1.0)
    }

    var gestationWeeks: Int {
        (gestationDays ?? 0) / 7
    }

    // MARK: - Factory Methods

    static func create(for cow: Cattle, method: BreedingMethod, in context: NSManagedObjectContext) -> PregnancyRecord {
        let record = PregnancyRecord(context: context)
        record.id = UUID()
        record.cow = cow
        record.breedingMethod = method.rawValue
        record.breedingDate = Date()
        record.status = PregnancyStatus.bred.rawValue
        record.createdAt = Date()
        record.modifiedAt = Date()

        // Calculate expected calving date (283 days from breeding)
        record.expectedCalvingDate = CattleValidation.gestationPeriod(from: Date())

        return record
    }

    // MARK: - Status Updates

    func confirm(method: PregnancyConfirmationMethod, on date: Date = Date()) {
        status = PregnancyStatus.confirmed.rawValue
        confirmedDate = date
        confirmationMethod = method.rawValue
        modifiedAt = Date()
    }

    func markAsOpen() {
        status = PregnancyStatus.open.rawValue
        modifiedAt = Date()
    }

    func markAsCalved() {
        status = PregnancyStatus.calved.rawValue
        outcome = "Calved"
        modifiedAt = Date()
    }

    func markAsLost(reason: String? = nil) {
        status = PregnancyStatus.lost.rawValue
        outcome = reason ?? "Lost"
        modifiedAt = Date()
    }

    // MARK: - Validation

    var isValid: Bool {
        guard cow != nil else { return false }
        guard breedingMethod != nil else { return false }
        guard status != nil else { return false }
        return true
    }
}
