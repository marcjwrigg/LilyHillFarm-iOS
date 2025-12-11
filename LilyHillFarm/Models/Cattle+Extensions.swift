//
//  Cattle+Extensions.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import Foundation
internal import CoreData

extension Cattle {

    // MARK: - Computed Properties

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return tagNumber ?? "Unknown"
    }

    var age: String {
        guard let dob = dateOfBirth else {
            return approximateAge ?? "Unknown"
        }

        let components = Calendar.current.dateComponents([.year, .month], from: dob, to: Date())

        if let years = components.year, let months = components.month {
            if years == 0 {
                return "\(months) month\(months == 1 ? "" : "s")"
            } else if months == 0 {
                return "\(years) year\(years == 1 ? "" : "s")"
            } else {
                return "\(years)y \(months)m"
            }
        }

        return "Unknown"
    }

    var ageInMonths: Int? {
        guard let dob = dateOfBirth else { return nil }
        let components = Calendar.current.dateComponents([.month], from: dob, to: Date())
        return components.month
    }

    var ageInDays: Int? {
        guard let dob = dateOfBirth else { return nil }
        let components = Calendar.current.dateComponents([.day], from: dob, to: Date())
        return components.day
    }

    var primaryPhoto: Photo? {
        let photoArray = photos?.allObjects as? [Photo] ?? []
        return photoArray.first(where: { $0.isPrimary }) ?? photoArray.first
    }

    var sortedPhotos: [Photo] {
        let photoArray = photos?.allObjects as? [Photo] ?? []
        return photoArray.sorted { ($0.dateTaken ?? Date.distantPast) > ($1.dateTaken ?? Date.distantPast) }
    }

    var sortedHealthRecords: [HealthRecord] {
        let records = healthRecords?.allObjects as? [HealthRecord] ?? []
        return records.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
    }

    var sortedCalvingRecords: [CalvingRecord] {
        let records = calvingRecordsAsDam?.allObjects as? [CalvingRecord] ?? []
        // Filter out deleted records
        let activeRecords = records.filter { $0.deletedAt == nil }
        return activeRecords.sorted { ($0.calvingDate ?? Date.distantPast) > ($1.calvingDate ?? Date.distantPast) }
    }

    var sortedPregnancyRecords: [PregnancyRecord] {
        let records = pregnancyRecordsAsCow?.allObjects as? [PregnancyRecord] ?? []
        // Filter out deleted records
        let activeRecords = records.filter { $0.deletedAt == nil }
        return activeRecords.sorted { ($0.breedingDate ?? Date.distantPast) > ($1.breedingDate ?? Date.distantPast) }
    }

    var sortedStageTransitions: [StageTransition] {
        let transitions = stageTransitions?.allObjects as? [StageTransition] ?? []
        return transitions.sorted { ($0.transitionDate ?? Date.distantPast) < ($1.transitionDate ?? Date.distantPast) }
    }

    var currentPregnancy: PregnancyRecord? {
        sortedPregnancyRecords.first { $0.status == PregnancyStatus.confirmed.rawValue || $0.status == PregnancyStatus.bred.rawValue || $0.status == PregnancyStatus.exposed.rawValue }
    }

    var pendingBreeding: PregnancyRecord? {
        sortedPregnancyRecords.first { $0.status == PregnancyStatus.pending.rawValue }
    }

    var isPregnant: Bool {
        currentPregnancy != nil
    }

    var offspringArray: [Cattle] {
        let offspringSet = offspring as? Set<Cattle> ?? []
        return Array(offspringSet).sorted { ($0.dateOfBirth ?? Date.distantPast) > ($1.dateOfBirth ?? Date.distantPast) }
    }

    var siredOffspringArray: [Cattle] {
        let siredSet = siredOffspring as? Set<Cattle> ?? []
        return Array(siredSet).sorted { ($0.dateOfBirth ?? Date.distantPast) > ($1.dateOfBirth ?? Date.distantPast) }
    }

    var offspringAsSire: [Cattle] {
        siredOffspringArray
    }

    var daysOnFeed: Int? {
        guard let startDate = finishingStartDate else { return nil }
        let components = Calendar.current.dateComponents([.day], from: startDate, to: Date())
        return components.day
    }

    var estimatedDaysUntilProcessing: Int? {
        guard let estimatedDate = estimatedProcessingDate else { return nil }
        let components = Calendar.current.dateComponents([.day], from: Date(), to: estimatedDate)
        return components.day
    }

    // MARK: - Stage Management

    func canPromoteToNextStage() -> Bool {
        return nextStage() != nil
    }

    func nextStage() -> CattleStage? {
        guard let currentStageEnum = CattleStage(rawValue: currentStage ?? "") else {
            return nil
        }

        // Context-aware stage progression based on production path
        let path = productionPath ?? ProductionPath.beefFinishing.rawValue

        switch currentStageEnum {
        case .calf:
            return .weanling

        case .weanling:
            // Check production path
            if path == ProductionPath.breeding.rawValue {
                return .breeding
            } else {
                return .stocker
            }

        case .stocker:
            // Check production path
            if path == ProductionPath.breeding.rawValue {
                return .breeding
            } else {
                return .feeder
            }

        case .feeder:
            // Feeder goes to processed
            return .processed

        case .breeding:
            // Breeding animals can go to processed when culled
            return .processed

        case .processed:
            return nil // Terminal stage
        }
    }

    func promoteToStage(_ newStage: CattleStage, weight: Decimal?, notes: String?, context: NSManagedObjectContext) {
        let oldStage = currentStage

        // Create transition record
        let transition = StageTransition(context: context)
        transition.id = UUID()
        transition.fromStage = oldStage
        transition.toStage = newStage.rawValue
        transition.transitionDate = Date()
        transition.weight = weight.map { NSDecimalNumber(decimal: $0) }
        transition.notes = notes
        transition.cattle = self
        transition.createdAt = Date()

        // Update cattle stage
        currentStage = newStage.rawValue

        // Update stage-specific fields
        switch newStage {
        case .weanling:
            weaningDate = Date()
            if let weight = weight {
                weaningWeight = NSDecimalNumber(decimal: weight)
            }
        case .feeder:
            finishingStartDate = Date()
        default:
            break
        }

        modifiedAt = Date()
    }

    // MARK: - Health Status

    var upcomingHealthAppointments: [HealthRecord] {
        sortedHealthRecords.filter {
            if let followUpDate = $0.followUpDate, !$0.followUpCompleted {
                return followUpDate >= Date()
            }
            return false
        }
    }

    var overdueHealthAppointments: [HealthRecord] {
        sortedHealthRecords.filter {
            if let followUpDate = $0.followUpDate, !$0.followUpCompleted {
                return followUpDate < Date()
            }
            return false
        }
    }

    var recentHealthIssues: [HealthRecord] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return sortedHealthRecords.filter {
            guard let date = $0.date else { return false }
            return date >= thirtyDaysAgo && $0.recordType == HealthRecordType.illness.rawValue
        }
    }

    // MARK: - Production Metrics

    var averageDailyGain: Decimal? {
        guard let daysOnFeed = daysOnFeed, daysOnFeed > 0,
              let currentWeight = currentWeight as? Decimal,
              let startDate = finishingStartDate,
              let startWeight = getWeightAtDate(startDate) else {
            return nil
        }

        let weightGain = currentWeight - startWeight
        return weightGain / Decimal(daysOnFeed)
    }

    func getWeightAtDate(_ date: Date) -> Decimal? {
        // Look for weight in stage transitions near that date
        let transition = sortedStageTransitions.first {
            guard let transDate = $0.transitionDate else { return false }
            return abs(transDate.timeIntervalSince(date)) < 86400
        }
        return transition?.weight as? Decimal
    }

    // MARK: - Tag Management

    var tagArray: [String] {
        get {
            guard let tagsString = tags, !tagsString.isEmpty else { return [] }

            // Try to parse as JSON array first (from Supabase: ["Dec 25 AI"])
            if tagsString.hasPrefix("[") && tagsString.hasSuffix("]") {
                if let data = tagsString.data(using: .utf8),
                   let jsonArray = try? JSONDecoder().decode([String].self, from: data) {
                    return jsonArray
                }
            }

            // Fallback to comma-separated format
            return tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            let uniqueTags = Array(Set(newValue)).filter { !$0.isEmpty }
            // Store as JSON array to match Supabase format
            if let jsonData = try? JSONEncoder().encode(uniqueTags),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                tags = jsonString
            } else {
                tags = uniqueTags.isEmpty ? nil : uniqueTags.joined(separator: ",")
            }
            modifiedAt = Date()
        }
    }

    // MARK: - Location Management

    var locationArray: [String] {
        get {
            // location is already [String]? in Core Data (Transformable with customClassName)
            return location ?? []
        }
        set {
            // Store directly as [String]?
            location = newValue.isEmpty ? nil : newValue
            modifiedAt = Date()
        }
    }

    var primaryLocation: String? {
        return locationArray.first
    }

    func hasTag(_ tag: String) -> Bool {
        return tagArray.contains(tag)
    }

    func addTag(_ tag: String) {
        let trimmedTag = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmedTag.isEmpty && !hasTag(trimmedTag) else { return }
        var tags = tagArray
        tags.append(trimmedTag)
        tagArray = tags
    }

    func removeTag(_ tag: String) {
        tagArray = tagArray.filter { $0 != tag }
    }

    func addTags(_ newTags: [String]) {
        var tags = tagArray
        for tag in newTags {
            let trimmedTag = tag.trimmingCharacters(in: .whitespaces)
            if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
                tags.append(trimmedTag)
            }
        }
        tagArray = tags
    }

    func removeTags(_ tagsToRemove: [String]) {
        tagArray = tagArray.filter { !tagsToRemove.contains($0) }
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let tagNumber = tagNumber, !tagNumber.isEmpty else { return false }
        guard let sex = sex, !sex.isEmpty else { return false }
        return true
    }

    // MARK: - Factory Methods

    static func create(in context: NSManagedObjectContext) -> Cattle {
        let cattle = Cattle(context: context)
        cattle.id = UUID()
        cattle.currentStatus = CattleStatus.active.rawValue
        cattle.currentStage = CattleStage.calf.rawValue
        cattle.productionPath = ProductionPath.beefFinishing.rawValue
        cattle.createdAt = Date()
        cattle.modifiedAt = Date()
        return cattle
    }
}
