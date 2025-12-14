//
//  PregnancyListView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct PregnancyListView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddPregnancy = false
    @State private var selectedStatus: PregnancyStatus?

    var activePregnancies: [PregnancyRecord] {
        cattle.sortedPregnancyRecords.filter {
            $0.status == PregnancyStatus.confirmed.rawValue ||
            $0.status == PregnancyStatus.bred.rawValue ||
            $0.status == PregnancyStatus.exposed.rawValue ||
            $0.status == PregnancyStatus.pending.rawValue
        }
    }

    var historicalPregnancies: [PregnancyRecord] {
        cattle.sortedPregnancyRecords.filter {
            $0.status == PregnancyStatus.calved.rawValue ||
            $0.status == PregnancyStatus.lost.rawValue
        }
    }

    var filteredPregnancies: [PregnancyRecord] {
        var records = cattle.sortedPregnancyRecords

        if let status = selectedStatus {
            records = records.filter { $0.status == status.rawValue }
        }

        return records
    }

    var overduePregnancies: [PregnancyRecord] {
        activePregnancies.filter { $0.isOverdue }
    }

    var upcomingCalvings: [PregnancyRecord] {
        activePregnancies.filter {
            guard let days = $0.daysUntilDue else { return false }
            return days > 0 && days <= 30
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status Filter
            if !cattle.sortedPregnancyRecords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All (\(cattle.sortedPregnancyRecords.count))",
                            isSelected: selectedStatus == nil,
                            action: {
                                selectedStatus = nil
                            }
                        )

                        ForEach(PregnancyStatus.allCases) { status in
                            let count = cattle.sortedPregnancyRecords.filter { $0.status == status.rawValue }.count
                            if count > 0 {
                                FilterChip(
                                    title: "\(status.displayName) (\(count))",
                                    isSelected: selectedStatus == status,
                                    action: {
                                        selectedStatus = status
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.white)

                Divider()
            }

            // Alert Cards
            if !overduePregnancies.isEmpty || !upcomingCalvings.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        if !overduePregnancies.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("\(overduePregnancies.count) Overdue")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }

                                ForEach(overduePregnancies, id: \.objectID) { pregnancy in
                                    NavigationLink(destination: PregnancyDetailView(pregnancy: pregnancy)) {
                                        PregnancyAlertRow(pregnancy: pregnancy)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.top)
                        }

                        if !upcomingCalvings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.blue)
                                    Text("Due in Next 30 Days")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }

                                ForEach(upcomingCalvings, id: \.objectID) { pregnancy in
                                    NavigationLink(destination: PregnancyDetailView(pregnancy: pregnancy)) {
                                        PregnancyAlertRow(pregnancy: pregnancy)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
                .frame(maxHeight: 200)

                Divider()
            }

            // Pregnancy List
            if filteredPregnancies.isEmpty {
                EmptyStateView(
                    icon: "heart.circle",
                    title: "No pregnancies",
                    message: selectedStatus == nil ? "Add a breeding record to track pregnancies" : "No \(selectedStatus?.displayName.lowercased() ?? "") pregnancies"
                )
            } else if selectedStatus == nil {
                // Show separated active and historical sections when no filter applied
                List {
                    if !activePregnancies.isEmpty {
                        Section {
                            ForEach(activePregnancies, id: \.objectID) { pregnancy in
                                NavigationLink(destination: PregnancyDetailView(pregnancy: pregnancy)) {
                                    PregnancyRowView(pregnancy: pregnancy)
                                }
                            }
                            .onDelete { offsets in
                                deleteSpecificPregnancies(offsets: offsets, from: activePregnancies)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "heart.circle.fill")
                                    .foregroundColor(.green)
                                Text("Current Pregnancy")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .textCase(nil)
                            .padding(.top, 4)
                        }
                    }

                    if !historicalPregnancies.isEmpty {
                        Section {
                            ForEach(historicalPregnancies, id: \.objectID) { pregnancy in
                                NavigationLink(destination: PregnancyDetailView(pregnancy: pregnancy)) {
                                    HistoricalPregnancyRowView(pregnancy: pregnancy)
                                }
                            }
                            .onDelete { offsets in
                                deleteSpecificPregnancies(offsets: offsets, from: historicalPregnancies)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.purple)
                                Text("Breeding & Calving History")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .textCase(nil)
                            .padding(.top, 8)
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                // Show filtered list when a status filter is applied
                List {
                    ForEach(filteredPregnancies, id: \.objectID) { pregnancy in
                        NavigationLink(destination: PregnancyDetailView(pregnancy: pregnancy)) {
                            PregnancyRowView(pregnancy: pregnancy)
                        }
                    }
                    .onDelete(perform: deletePregnancies)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Breeding Records")
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
            #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingAddPregnancy = true }) {
                    Label("Add Record", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPregnancy) {
            AddPregnancyView(cattle: cattle)
        }
    }

    // MARK: - Delete Pregnancies

    private func deletePregnancies(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredPregnancies[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting pregnancy: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteSpecificPregnancies(offsets: IndexSet, from list: [PregnancyRecord]) {
        withAnimation {
            offsets.map { list[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting pregnancy: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Historical Pregnancy Row View

struct HistoricalPregnancyRowView: View {
    @ObservedObject var pregnancy: PregnancyRecord
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch calving record for this pregnancy
    @FetchRequest private var calvingRecords: FetchedResults<CalvingRecord>

    init(pregnancy: PregnancyRecord) {
        self.pregnancy = pregnancy

        // Fetch calving record for this pregnancy
        _calvingRecords = FetchRequest<CalvingRecord>(
            sortDescriptors: [],
            predicate: pregnancy.id != nil
                ? NSPredicate(format: "pregnancyId == %@", pregnancy.id! as CVarArg)
                : NSPredicate(value: false)
        )
    }

    var statusColor: Color {
        guard let status = PregnancyStatus(rawValue: pregnancy.status ?? "") else {
            return .gray
        }

        switch status {
        case .calved:
            return .purple
        case .lost:
            return .red
        default:
            return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: calvingRecords.first != nil ? "heart.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(statusColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(calvingRecords.first != nil ? "Complete Breeding Cycle" : "Breeding Record")
                    .font(.headline)
                    .foregroundColor(.primary)

                // Breeding info
                HStack(spacing: 4) {
                    Text("Bred:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(pregnancy.displayBreedingDate)
                        .font(.caption)
                        .fontWeight(.medium)

                    if let method = pregnancy.breedingMethod {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(method)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Sire info
                if let sire = pregnancy.bull {
                    HStack(spacing: 4) {
                        Text("Sire:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(sire.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                } else if let externalBull = pregnancy.externalBullName, !externalBull.isEmpty {
                    HStack(spacing: 4) {
                        Text("Sire:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(externalBull)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                // Calving info
                if let calving = calvingRecords.first {
                    HStack(spacing: 4) {
                        Text("Calved:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(calving.displayDate)
                            .font(.caption)
                            .fontWeight(.medium)

                        if let calf = calving.calf, let sex = calf.sex {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(sex)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let weight = calving.calfBirthWeight as? Decimal, weight > 0 {
                                Text("\(weight as NSNumber) lbs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Link to calf
                    if let calf = calving.calf {
                        HStack(spacing: 4) {
                            Image(systemName: "link.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("Calf: \(calf.displayName)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Pregnancy Alert Row

struct PregnancyAlertRow: View {
    @ObservedObject var pregnancy: PregnancyRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let sire = pregnancy.bull {
                    Text("Sire: \(sire.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text("Unknown Sire")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if pregnancy.expectedCalvingDate != nil {
                    Text("Due: \(pregnancy.displayDueDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Breeding: \(pregnancy.displayBreedingDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let days = pregnancy.daysUntilDue {
                if days < 0 {
                    Text("\(-days)d overdue")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(4)
                } else {
                    Text("\(days)d")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        PregnancyListView(cattle: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            cattle.tagNumber = "LHF-001"
            cattle.name = "Bessie"
            return cattle
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
