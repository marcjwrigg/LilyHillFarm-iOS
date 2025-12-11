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

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "currentStatus == %@", CattleStatus.active.rawValue),
        animation: .default)
    private var activeCattle: FetchedResults<Cattle>

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
            let days0 = getEarliestCalvingDays($0) ?? Int.max
            let days1 = getEarliestCalvingDays($1) ?? Int.max
            // Handle negative days (overdue) - they should come first
            if days0 < 0 && days1 >= 0 { return true }
            if days0 >= 0 && days1 < 0 { return false }
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
        let startOfYear = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date()))!
        return allCalvingRecords.filter {
            guard let date = $0.calvingDate else { return false }
            return date >= startOfYear
        }.count
    }

    var breedableCattle: [Cattle] {
        activeCattle.filter {
            $0.sex == CattleSex.cow.rawValue || $0.sex == CattleSex.heifer.rawValue
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
        InfoCard(title: "Active Pregnancies", subtitle: "Sorted by closest to furthest calving date") {
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
        InfoCard(title: "Recent Calvings", subtitle: "Latest calving records") {
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

#Preview {
    BreedingDashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
