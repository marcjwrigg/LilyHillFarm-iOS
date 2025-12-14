//
//  BreedingDashboardView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BreedingDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedDaysFilter: Int? = 30
    @State private var showAllPregnancies = false
    @State private var isActivePregnanciesExpanded = true
    @State private var isRecentCalvingsExpanded = true

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "currentStatus == %@", CattleStatus.active.rawValue),
        animation: .default)
    private var activeCattle: FetchedResults<Cattle>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default)
    private var allCattle: FetchedResults<Cattle>

    var allPregnancies: [PregnancyRecord] {
        activeCattle.flatMap { $0.sortedPregnancyRecords }
            .sorted { ($0.breedingDate ?? Date.distantPast) > ($1.breedingDate ?? Date.distantPast) }
    }

    var activePregnancies: [PregnancyRecord] {
        let active = allPregnancies.filter {
            $0.status == PregnancyStatus.bred.rawValue ||
            $0.status == PregnancyStatus.exposed.rawValue ||
            $0.status == PregnancyStatus.confirmed.rawValue
        }

        // Helper function to get the earliest calving date (for filtering and sorting)
        func getEarliestCalvingDays(_ pregnancy: PregnancyRecord) -> Int? {
            // Use start of calving window if available, otherwise use single due date
            if let calvingStart = pregnancy.expectedCalvingStartDate {
                return Calendar.current.dateComponents([.day], from: Date(), to: calvingStart).day ?? 0
            } else if let calvingDate = pregnancy.expectedCalvingDate {
                return Calendar.current.dateComponents([.day], from: Date(), to: calvingDate).day ?? 0
            }
            return nil
        }

        // Helper function to check if pregnancy is truly overdue (past END date)
        func isOverdue(_ pregnancy: PregnancyRecord) -> Bool {
            if let calvingEnd = pregnancy.expectedCalvingEndDate {
                return Date() > calvingEnd
            } else if let calvingDate = pregnancy.expectedCalvingDate {
                return Date() > calvingDate
            }
            return false
        }

        // Filter by selected days if applicable
        let filtered: [PregnancyRecord]
        if let daysFilter = selectedDaysFilter {
            filtered = active.filter {
                guard let days = getEarliestCalvingDays($0) else { return false }
                // Include overdue (negative days) and pregnancies within the filter window
                return days <= daysFilter
            }
        } else {
            filtered = active
        }

        // Sort by earliest calving date (closest first)
        return filtered.sorted {
            let overdue0 = isOverdue($0)
            let overdue1 = isOverdue($1)

            // Truly overdue pregnancies come first
            if overdue0 && !overdue1 { return true }
            if !overdue0 && overdue1 { return false }

            // Otherwise sort by earliest calving date
            let days0 = getEarliestCalvingDays($0) ?? Int.max
            let days1 = getEarliestCalvingDays($1) ?? Int.max
            return abs(days0) < abs(days1)
        }
    }

    var allActivePregnancies: [PregnancyRecord] {
        allPregnancies.filter {
            $0.status == PregnancyStatus.bred.rawValue ||
            $0.status == PregnancyStatus.exposed.rawValue ||
            $0.status == PregnancyStatus.confirmed.rawValue
        }
    }

    var bredCount: Int {
        allActivePregnancies.filter { $0.status == PregnancyStatus.bred.rawValue }.count
    }

    var exposedCount: Int {
        allActivePregnancies.filter { $0.status == PregnancyStatus.exposed.rawValue }.count
    }

    var confirmedCount: Int {
        allActivePregnancies.filter { $0.status == PregnancyStatus.confirmed.rawValue }.count
    }

    var overduePregnancies: [PregnancyRecord] {
        allActivePregnancies.filter { pregnancy in
            // Check if calving window end date has passed, or single due date has passed
            if let calvingEnd = pregnancy.expectedCalvingEndDate {
                return Date() > calvingEnd
            } else if let calvingDate = pregnancy.expectedCalvingDate {
                return Date() > calvingDate
            }
            return false
        }
    }

    var upcomingCalvings: [PregnancyRecord] {
        allActivePregnancies
            .filter { pregnancy in
                // Use start of calving window if available, otherwise use single due date
                let earliestDate: Date?
                if let calvingStart = pregnancy.expectedCalvingStartDate {
                    earliestDate = calvingStart
                } else {
                    earliestDate = pregnancy.expectedCalvingDate
                }

                guard let date = earliestDate else { return false }
                let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
                return days > 0 && days <= 30
            }
            .sorted { pregnancy0, pregnancy1 in
                // Sort by earliest calving date
                let date0 = pregnancy0.expectedCalvingStartDate ?? pregnancy0.expectedCalvingDate ?? Date.distantFuture
                let date1 = pregnancy1.expectedCalvingStartDate ?? pregnancy1.expectedCalvingDate ?? Date.distantFuture
                return date0 < date1
            }
    }

    var allCalvingRecords: [CalvingRecord] {
        activeCattle.flatMap { $0.sortedCalvingRecords }
            .sorted { ($0.calvingDate ?? Date.distantPast) > ($1.calvingDate ?? Date.distantPast) }
    }

    var calvingsThisYear: Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        return allCalvingRecords.filter {
            guard let date = $0.calvingDate else { return false }
            let year = Calendar.current.component(.year, from: date)
            return year == currentYear
        }.count
    }

    var breedableCattle: [Cattle] {
        activeCattle.filter {
            $0.sex == CattleSex.cow.rawValue || $0.sex == CattleSex.heifer.rawValue
        }
    }

    // MARK: - Breeding Performance Stats

    var avgDaysPostPartum: Int? {
        var intervals: [Int] = []

        // Materialize the cattle array to avoid threading issues
        let cattleArray = Array(breedableCattle)

        for cattle in cattleArray {
            // Materialize relationships to arrays before iterating
            let calvings = Array(cattle.sortedCalvingRecords)
            let pregnancies = Array(cattle.sortedPregnancyRecords).sorted {
                let date0 = $0.breedingDate ?? $0.breedingStartDate ?? Date.distantPast
                let date1 = $1.breedingDate ?? $1.breedingStartDate ?? Date.distantPast
                return date0 < date1
            }

            for calving in calvings {
                guard let calvingDate = calving.calvingDate else { continue }

                // Find first pregnancy where breeding date (or breeding_start_date) is after this calving date
                if let nextBreeding = pregnancies.first(where: { pregnancy in
                    let breedingDate = pregnancy.breedingDate ?? pregnancy.breedingStartDate
                    guard let date = breedingDate else { return false }
                    return date > calvingDate
                }) {
                    let breedingDate = nextBreeding.breedingDate ?? nextBreeding.breedingStartDate!
                    let days = Calendar.current.dateComponents([.day], from: calvingDate, to: breedingDate).day ?? 0
                    if days > 0 && days < 365 { // Sanity check
                        intervals.append(days)
                    }
                }
            }
        }

        guard !intervals.isEmpty else { return nil }
        let average = Double(intervals.reduce(0, +)) / Double(intervals.count)
        return Int(average.rounded())
    }

    var avgDaysBetweenCalving: Int? {
        var intervals: [Int] = []

        // Materialize the cattle array to avoid threading issues
        let cattleArray = Array(breedableCattle)

        for cattle in cattleArray {
            // Materialize the relationship to an array first, then reverse and extract dates
            let calvings = Array(cattle.sortedCalvingRecords).reversed()
                .compactMap { $0.calvingDate }

            // Need at least 2 calvings to calculate intervals
            guard calvings.count > 1 else { continue }

            for i in 1..<calvings.count {
                let days = Calendar.current.dateComponents([.day], from: calvings[i-1], to: calvings[i]).day ?? 0
                if days > 0 {
                    intervals.append(days)
                }
            }
        }

        guard !intervals.isEmpty else { return nil }
        let average = Double(intervals.reduce(0, +)) / Double(intervals.count)
        return Int(average.rounded())
    }

    var bullHeiferRatio: String {
        // Use ALL cattle (not just active) for all-time ratio - materialize to avoid threading issues
        let cattleArray = Array(allCattle)

        // Only include offspring with a dam_id (born on farm)
        let allOffspring = cattleArray.filter { cattle in
            cattle.dam != nil
        }

        let bulls = allOffspring.filter { $0.sex == CattleSex.bull.rawValue || $0.sex == CattleSex.steer.rawValue }.count
        let heifers = allOffspring.filter { $0.sex == CattleSex.heifer.rawValue || $0.sex == CattleSex.cow.rawValue }.count

        if heifers > 0 {
            return "\(bulls):\(heifers)"
        } else if bulls > 0 {
            return "\(bulls):0"
        } else {
            return "—"
        }
    }

    var bullHeiferRatioSimplified: String {
        // Use ALL cattle (not just active) for all-time ratio - materialize to avoid threading issues
        let cattleArray = Array(allCattle)

        // Only include offspring with a dam_id (born on farm)
        let allOffspring = cattleArray.filter { cattle in
            cattle.dam != nil
        }

        let bulls = allOffspring.filter { $0.sex == CattleSex.bull.rawValue || $0.sex == CattleSex.steer.rawValue }.count
        let heifers = allOffspring.filter { $0.sex == CattleSex.heifer.rawValue || $0.sex == CattleSex.cow.rawValue }.count

        if heifers > 0 {
            let ratio = Double(bulls) / Double(heifers)
            return "(\(String(format: "%.2f", ratio)):1)"
        } else if bulls > 0 {
            return "(\(bulls):0)"
        } else {
            return ""
        }
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    // Stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Bred",
                            value: "\(bredCount)",
                            icon: "heart",
                            color: .blue,
                            subtitle: "Recently bred, not confirmed"
                        )

                        StatCard(
                            title: "Exposed",
                            value: "\(exposedCount)",
                            icon: "heart.circle",
                            color: .orange,
                            subtitle: "Exposed to bull during season"
                        )

                        StatCard(
                            title: "Confirmed",
                            value: "\(confirmedCount)",
                            icon: "checkmark.circle",
                            color: .green,
                            subtitle: "Pregnancy confirmed"
                        )

                        StatCard(
                            title: "Calvings This Year",
                            value: "\(calvingsThisYear)",
                            icon: "figure.and.child.holdinghands",
                            color: .gray,
                            subtitle: "\(Calendar.current.component(.year, from: Date()))"
                        )
                    }
                    .padding(.horizontal)

                    // Breeding Performance Metrics
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Avg Days Post Partum",
                            value: avgDaysPostPartum.map { "\($0)" } ?? "—",
                            icon: "calendar",
                            color: .blue,
                            subtitle: "Days until rebred after calving"
                        )

                        StatCard(
                            title: "Avg Days Between Calving",
                            value: avgDaysBetweenCalving.map { "\($0)" } ?? "—",
                            icon: "calendar.badge.clock",
                            color: .purple,
                            subtitle: "Calving interval"
                        )

                        BullHeiferRatioCard(
                            ratio: bullHeiferRatio,
                            simplified: bullHeiferRatioSimplified
                        )
                    }
                    .padding(.horizontal)

                    // Two Column Layout
                    #if os(iOS)
                    VStack(spacing: 16) {
                        // Active Pregnancies
                        activePregnanciesCard

                        // Recent Calving Records
                        recentCalvingsCard
                    }
                    .padding(.horizontal)
                    #else
                    HStack(alignment: .top, spacing: 16) {
                        // Active Pregnancies
                        activePregnanciesCard

                        // Recent Calving Records
                        recentCalvingsCard
                    }
                    .padding(.horizontal)
                    #endif
                }
                .padding(.vertical)
            #if os(macOS)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
        }
        .navigationTitle("Breeding Dashboard")
    }

    // MARK: - Active Pregnancies Card

    private var activePregnanciesCard: some View {
        InfoCard(title: "Active Pregnancies", subtitle: "Sorted by closest to furthest calving date", isExpanded: $isActivePregnanciesExpanded) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "7 Days",
                        isSelected: selectedDaysFilter == 7,
                        action: { selectedDaysFilter = 7; showAllPregnancies = false }
                    )
                    FilterChip(
                        title: "14 Days",
                        isSelected: selectedDaysFilter == 14,
                        action: { selectedDaysFilter = 14; showAllPregnancies = false }
                    )
                    FilterChip(
                        title: "30 Days",
                        isSelected: selectedDaysFilter == 30,
                        action: { selectedDaysFilter = 30; showAllPregnancies = false }
                    )
                    FilterChip(
                        title: "60 Days",
                        isSelected: selectedDaysFilter == 60,
                        action: { selectedDaysFilter = 60; showAllPregnancies = false }
                    )
                    FilterChip(
                        title: "All",
                        isSelected: selectedDaysFilter == nil,
                        action: { selectedDaysFilter = nil; showAllPregnancies = false }
                    )
                }
            }
            .padding(.bottom, 12)

            if activePregnancies.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No active pregnancies")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let displayCount = showAllPregnancies ? activePregnancies.count : min(10, activePregnancies.count)

                ForEach(activePregnancies.prefix(displayCount), id: \.objectID) { pregnancy in
                    if let cattle = pregnancy.cow {
                        NavigationLink(destination: PregnancyDetailView(pregnancy: pregnancy)) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cattle.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("#\(cattle.tagNumber ?? "Unknown")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // Days until calving badge - handle both single date and range
                                    if let calvingStart = pregnancy.expectedCalvingStartDate,
                                       let calvingEnd = pregnancy.expectedCalvingEndDate {
                                        // Calving window (for exposed pregnancies)
                                        let daysUntilStart = Calendar.current.dateComponents([.day], from: Date(), to: calvingStart).day ?? 0
                                        let daysUntilEnd = Calendar.current.dateComponents([.day], from: Date(), to: calvingEnd).day ?? 0

                                        VStack(spacing: 2) {
                                            if daysUntilEnd < 0 {
                                                Text("Past")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.red)
                                                Text("window")
                                                    .font(.caption2)
                                                    .foregroundColor(.red)
                                            } else if daysUntilStart <= 0 && daysUntilEnd >= 0 {
                                                Text("\(daysUntilEnd)d")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.orange)
                                                Text("in window")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            } else {
                                                Text("\(daysUntilStart)-\(daysUntilEnd)d")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(daysUntilStart <= 7 ? .orange : daysUntilStart <= 30 ? .blue : .secondary)
                                                Text("window")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    } else if let days = pregnancy.daysUntilDue {
                                        // Single due date
                                        VStack(spacing: 2) {
                                            if days < 0 {
                                                Text("\(-days)d")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.red)
                                                Text("overdue")
                                                    .font(.caption2)
                                                    .foregroundColor(.red)
                                            } else {
                                                Text("\(days)d")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(days <= 7 ? .orange : days <= 30 ? .blue : .secondary)
                                                Text("to go")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }

                                // Bull info
                                if let bull = pregnancy.bull {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("Bull:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(bull.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        if let bullTag = bull.tagNumber {
                                            Text("(#\(bullTag))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } else if let externalBullName = pregnancy.externalBullName {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("Bull:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(externalBullName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    }
                                }

                                // Due date and status
                                HStack {
                                    if let expectedDate = pregnancy.expectedCalvingStartDate ?? pregnancy.expectedCalvingDate {
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text("Due: \(expectedDate, style: .date)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    // Status Badge
                                    if let status = pregnancy.status {
                                        let statusColor = getStatusColor(status)
                                        Text(status.capitalized)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(statusColor.opacity(0.15))
                                            .foregroundColor(statusColor)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if pregnancy.objectID != activePregnancies.prefix(displayCount).last?.objectID {
                            Divider()
                        }
                    }
                }

                // Show more/less button
                if activePregnancies.count > 10 {
                    Button(action: { showAllPregnancies.toggle() }) {
                        HStack {
                            Text(showAllPregnancies ? "Show Less" : "Show More (\(activePregnancies.count - 10) more)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: showAllPregnancies ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recent Calvings Card

    private var recentCalvingsCard: some View {
        InfoCard(title: "Recent Calvings", subtitle: "Latest calving records", isExpanded: $isRecentCalvingsExpanded) {
            if allCalvingRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.and.child.holdinghands")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No calving records")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(allCalvingRecords.prefix(15), id: \.objectID) { record in
                    NavigationLink(destination: CalvingDetailView(calvingRecord: record)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let dam = record.dam {
                                        Text(dam.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("#\(dam.tagNumber ?? "Unknown")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Unknown Dam")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    if let calvingDate = record.calvingDate {
                                        Text(calvingDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .fontWeight(.medium)
                                    }
                                }
                            }

                            if let calf = record.calf {
                                HStack {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Calf: \(calf.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let calfTag = calf.tagNumber {
                                        Text("(#\(calfTag))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            if let difficulty = record.difficulty, difficulty != "unassisted" {
                                HStack {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text(difficulty.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if record.objectID != allCalvingRecords.prefix(15).last?.objectID {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "bred":
            return .blue
        case "exposed":
            return .orange
        case "confirmed":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Bull:Heifer Ratio Card

struct BullHeiferRatioCard: View {
    let ratio: String
    let simplified: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.indigo)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ratio)
                    .font(.title)
                    .fontWeight(.bold)
                if !simplified.isEmpty {
                    Text(simplified)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text("Bull:Heifer Ratio")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("All-time offspring ratio")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    BreedingDashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
