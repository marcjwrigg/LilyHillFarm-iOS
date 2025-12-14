//
//  HealthDashboardView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct HealthDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var isFollowUpExpanded = true
    @State private var isWorstOffendersExpanded = true
    @State private var isRecentRecordsExpanded = true

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "currentStatus == %@", CattleStatus.active.rawValue),
        animation: .default)
    private var activeCattle: FetchedResults<Cattle>

    var cattleWithUpcomingAppointments: [Cattle] {
        activeCattle.filter { !$0.upcomingHealthAppointments.isEmpty }
    }

    var cattleWithOverdueAppointments: [Cattle] {
        activeCattle.filter { !$0.overdueHealthAppointments.isEmpty }
    }

    var recentHealthIssues: [(Cattle, [HealthRecord])] {
        activeCattle.compactMap { cattle in
            let issues = cattle.recentHealthIssues
            return issues.isEmpty ? nil : (cattle, issues)
        }
    }

    var allHealthRecords: [HealthRecord] {
        activeCattle.flatMap { $0.sortedHealthRecords }
            .sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
    }

    var allFollowUpRecords: [(Cattle, HealthRecord)] {
        activeCattle.flatMap { cattle in
            cattle.sortedHealthRecords
                .filter { $0.followUpDate != nil && !$0.followUpCompleted }
                .map { (cattle, $0) }
        }
        .sorted { ($0.1.followUpDate ?? Date.distantFuture) < ($1.1.followUpDate ?? Date.distantFuture) }
    }

    var worstOffenders: [(Cattle, Int)] {
        let cattleWithTreatments = activeCattle.compactMap { cattle -> (Cattle, Int)? in
            let treatmentCount = cattle.sortedHealthRecords.filter {
                $0.recordType == LegacyHealthRecordType.treatment.rawValue ||
                $0.recordType == LegacyHealthRecordType.injury.rawValue ||
                $0.recordType == LegacyHealthRecordType.illness.rawValue
            }.count
            return treatmentCount > 0 ? (cattle, treatmentCount) : nil
        }
        return cattleWithTreatments.sorted { $0.1 > $1.1 }.prefix(5).map { $0 }
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    // Stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Total Records",
                            value: "\(allHealthRecords.count)",
                            icon: "heart.text.square",
                            color: .gray,
                            subtitle: "All time"
                        )

                        StatCard(
                            title: "Recent Activity",
                            value: "\(recentRecordsCount)",
                            icon: "checkmark.circle",
                            color: .green,
                            subtitle: "Last 30 days"
                        )

                        StatCard(
                            title: "Vaccinations",
                            value: "\(recentVaccinationsCount)",
                            icon: "syringe",
                            color: .blue,
                            subtitle: "Last 30 days"
                        )

                        StatCard(
                            title: "Treatments",
                            value: "\(recentTreatmentsCount)",
                            icon: "cross.case",
                            color: .orange,
                            subtitle: "Last 30 days"
                        )
                    }
                    .padding(.horizontal)

                    // Two Column Layout
                    #if os(iOS)
                    VStack(spacing: 16) {
                        // Left Column
                        VStack(spacing: 16) {
                            followUpRequiredCard
                            worstOffendersCard
                        }

                        // Right Column
                        recentHealthRecordsCard
                    }
                    .padding(.horizontal)
                    #else
                    HStack(alignment: .top, spacing: 16) {
                        // Left Column
                        VStack(spacing: 16) {
                            followUpRequiredCard
                            worstOffendersCard
                        }
                        .frame(maxWidth: .infinity)

                        // Right Column
                        recentHealthRecordsCard
                            .frame(maxWidth: .infinity)
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
        .navigationTitle("Health Dashboard")
    }

    // MARK: - Follow-up Required Card

    private var followUpRequiredCard: some View {
        InfoCard(title: "Follow-up Required", subtitle: "Health records requiring follow-up treatment", isExpanded: $isFollowUpExpanded) {
            if allFollowUpRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("No follow-ups required")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(allFollowUpRecords.prefix(10), id: \.1.objectID) { cattle, record in
                    NavigationLink(destination: CattleDetailView(cattle: cattle)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.displayTypeWithCondition)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    HStack(spacing: 4) {
                                        Text("#\(cattle.tagNumber ?? "Unknown")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let name = cattle.name {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(name)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    if let followUpDate = record.followUpDate {
                                        let isOverdue = followUpDate < Date()
                                        Text(followUpDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(isOverdue ? .red : .primary)
                                            .fontWeight(isOverdue ? .medium : .regular)
                                        if isOverdue {
                                            Text("Overdue")
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red)
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if record.objectID != allFollowUpRecords.prefix(10).last?.1.objectID {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Worst Offenders Card

    private var worstOffendersCard: some View {
        InfoCard(title: "Worst Offenders", subtitle: "Animals with most treatments/injuries", isExpanded: $isWorstOffendersExpanded) {
            if worstOffenders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(worstOffenders, id: \.0.objectID) { cattle, count in
                    NavigationLink(destination: CattleDetailView(cattle: cattle)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("#\(cattle.tagNumber ?? "Unknown")")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if let name = cattle.name {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("\(count) treatment\(count == 1 ? "" : "s")/injur\(count == 1 ? "y" : "ies")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Text("\(count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if cattle.objectID != worstOffenders.last?.0.objectID {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Recent Health Records Card

    private var recentHealthRecordsCard: some View {
        InfoCard(title: "Recent Health Records", subtitle: "Latest medical history and treatments", isExpanded: $isRecentRecordsExpanded) {
            if allHealthRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No health records found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(allHealthRecords.prefix(20), id: \.objectID) { record in
                    NavigationLink(destination: HealthRecordDetailView(record: record)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.displayTypeWithCondition)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    HStack(spacing: 4) {
                                        Text("#\(record.cattle?.tagNumber ?? "Unknown")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let name = record.cattle?.name {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(name)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    if let treatment = record.treatment, !treatment.isEmpty {
                                        HStack {
                                            Text("Treatment:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fontWeight(.medium)
                                            Text(treatment)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    if let medication = record.medication, !medication.isEmpty {
                                        HStack {
                                            Text("Medication:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fontWeight(.medium)
                                            Text(medication)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if let dosage = record.dosage, !dosage.isEmpty {
                                                Text("(\(dosage))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }

                                    if let vet = record.veterinarian, !vet.isEmpty {
                                        HStack {
                                            Text("Veterinarian:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fontWeight(.medium)
                                            Text(vet)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    if let notes = record.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    if let date = record.date {
                                        Text(date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .fontWeight(.medium)
                                    }
                                    if let cost = record.cost as? Decimal, cost > 0 {
                                        Text("$\(cost as NSNumber, formatter: costFormatter)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if record.objectID != allHealthRecords.prefix(20).last?.objectID {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getRecordTypeColor(_ recordType: String) -> Color {
        switch recordType.lowercased() {
        case "vaccination":
            return .blue
        case "treatment":
            return .red
        case "checkup":
            return .green
        case "injury":
            return .orange
        case "illness":
            return .purple
        default:
            return .gray
        }
    }

    private var costFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    // MARK: - Computed Stats

    private var recentRecordsCount: Int {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return allHealthRecords.filter {
            guard let date = $0.date else { return false }
            return date >= thirtyDaysAgo
        }.count
    }

    private var recentVaccinationsCount: Int {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return allHealthRecords.filter {
            guard let date = $0.date else { return false }
            return date >= thirtyDaysAgo && $0.recordType == LegacyHealthRecordType.vaccination.rawValue
        }.count
    }

    private var recentTreatmentsCount: Int {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return allHealthRecords.filter {
            guard let date = $0.date else { return false }
            return date >= thirtyDaysAgo && $0.recordType == LegacyHealthRecordType.treatment.rawValue
        }.count
    }
}

// MARK: - Alert Card Component

struct AlertCard<Content: View>: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let content: Content

    init(title: String, count: Int, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.count = count
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            Divider()

            VStack(spacing: 8) {
                content
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    HealthDashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
