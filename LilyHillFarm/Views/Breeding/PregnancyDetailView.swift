//
//  PregnancyDetailView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct PregnancyDetailView: View {
    @ObservedObject var pregnancy: PregnancyRecord
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingRecordCalving = false
    @State private var showingDeleteAlert = false
    @State private var showingEdit = false
    @Environment(\.dismiss) private var dismiss

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
        case .pending:
            return .indigo
        case .bred:
            return .orange
        case .exposed:
            return .yellow
        case .confirmed:
            return .green
        case .open:
            return .gray
        case .calved:
            return .blue
        case .lost:
            return .red
        }
    }

    var canRecordCalving: Bool {
        // Can only record calving if no calving record exists yet
        calvingRecords.first == nil &&
        (pregnancy.status == PregnancyStatus.confirmed.rawValue ||
         pregnancy.status == PregnancyStatus.bred.rawValue ||
         pregnancy.status == PregnancyStatus.exposed.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Header
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(statusColor)

                    Text(pregnancy.displayStatus)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Due Date Status or Calving Status
                    if let calving = calvingRecords.first {
                        // Show calving info if calving record exists
                        if let calvingDate = calving.calvingDate {
                            Label("Calved on \(formatDate(calvingDate))", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundColor(.green)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    } else if let calvingStart = pregnancy.expectedCalvingStartDate,
                              let calvingEnd = pregnancy.expectedCalvingEndDate {
                        // Calving date range (for exposed pregnancies)
                        let daysUntilStart = Calendar.current.dateComponents([.day], from: Date(), to: calvingStart).day ?? 0
                        let daysUntilEnd = Calendar.current.dateComponents([.day], from: Date(), to: calvingEnd).day ?? 0

                        if daysUntilEnd < 0 {
                            // Entire window has passed
                            Label("Calving window ended \(-daysUntilEnd) days ago", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        } else if daysUntilStart <= 0 && daysUntilEnd >= 0 {
                            // Currently in the calving window
                            Label("In calving window (ends in \(daysUntilEnd) days)", systemImage: "calendar.badge.clock")
                                .font(.headline)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            // Window starts in the future
                            Label("Calving window starts in \(daysUntilStart) days", systemImage: "calendar.badge.clock")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    } else if let days = pregnancy.daysUntilDue {
                        // Single due date
                        if days < 0 {
                            Label("\(-days) days overdue", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            Label("Due in \(days) days", systemImage: "calendar.badge.clock")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }

                    // Record Calving Button
                    if canRecordCalving {
                        Button(action: { showingRecordCalving = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Record Calving")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                .padding(.top)

                // Dam Information
                InfoCard(title: "Dam") {
                    if let dam = pregnancy.cow {
                        NavigationLink(destination: CattleDetailView(cattle: dam)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dam.displayName)
                                        .font(.headline)
                                    Text(dam.tagNumber ?? "No Tag")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Unknown Dam")
                            .foregroundColor(.secondary)
                    }
                }

                // Sire Information
                InfoCard(title: "Sire") {
                    if let sire = pregnancy.bull {
                        NavigationLink(destination: CattleDetailView(cattle: sire)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sire.displayName)
                                        .font(.headline)
                                    Text(sire.tagNumber ?? "No Tag")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let breed = sire.breed?.name {
                                        Text(breed)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else if let externalBullName = pregnancy.externalBullName, !externalBullName.isEmpty {
                        // AI bull (external)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(externalBullName)
                                .font(.headline)
                            Text("AI Bull")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let registration = pregnancy.externalBullRegistration, !registration.isEmpty {
                                Text("Reg: \(registration)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Unknown Sire")
                            .foregroundColor(.secondary)
                    }
                }

                // Calf Information (if calving record exists)
                if let calving = calvingRecords.first, let calf = calving.calf {
                    InfoCard(title: "Calf") {
                        NavigationLink(destination: CattleDetailView(cattle: calf)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(calf.displayName)
                                        .font(.headline)
                                    Text(calf.tagNumber ?? "No Tag")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let breed = calf.breed?.name {
                                        Text(breed)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Divider()

                        if let weight = calving.calfBirthWeight as? Decimal, weight > 0 {
                            InfoRow(label: "Birth Weight", value: "\(weight as NSNumber) lbs")
                        }

                        if let sex = calf.sex {
                            InfoRow(label: "Sex", value: sex)
                        }

                        InfoRow(label: "Current Age", value: calf.age)
                    }
                }

                // Breeding Details
                InfoCard(title: "Breeding Details") {
                    // Check if breeding season dates exist
                    if let startDate = pregnancy.breedingStartDate,
                       let endDate = pregnancy.breedingEndDate {
                        InfoRow(label: "Breeding Season", value: "")
                        HStack {
                            Text("Start:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDate(startDate))
                                .font(.caption)
                        }
                        .padding(.leading, 16)
                        HStack {
                            Text("End:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDate(endDate))
                                .font(.caption)
                        }
                        .padding(.leading, 16)
                    } else {
                        InfoRow(label: "Breeding Date", value: pregnancy.displayBreedingDate)
                    }

                    InfoRow(label: "Method", value: pregnancy.displayMethod)

                    // AI details
                    if let aiTech = pregnancy.aiTechnician, !aiTech.isEmpty {
                        InfoRow(label: "AI Technician", value: aiTech)
                    }

                    if let semenSource = pregnancy.semenSource, !semenSource.isEmpty {
                        InfoRow(label: "Semen Source", value: semenSource)
                    }

                    if pregnancy.expectedCalvingDate != nil {
                        Divider()

                        // Check if calving window exists
                        if let calvingStart = pregnancy.expectedCalvingStartDate,
                           let calvingEnd = pregnancy.expectedCalvingEndDate {
                            InfoRow(label: "Estimated Calving Window", value: "")
                            HStack {
                                Text("Start:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDate(calvingStart))
                                    .font(.caption)
                            }
                            .padding(.leading, 16)
                            HStack {
                                Text("End:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDate(calvingEnd))
                                    .font(.caption)
                            }
                            .padding(.leading, 16)
                        } else {
                            InfoRow(label: "Estimated Due Date", value: pregnancy.displayDueDate)
                        }

                        InfoRow(label: "Gestation Days", value: "\(pregnancy.gestationDays ?? 0)")
                    }

                    if pregnancy.confirmedDate != nil {
                        Divider()
                        InfoRow(label: "Confirmation Date", value: pregnancy.displayConfirmationDate)
                        if let confirmMethod = pregnancy.confirmationMethod {
                            InfoRow(label: "Confirmation Method", value: confirmMethod)
                        }
                    }
                }

                // Calving Details (if calving record exists)
                if let calving = calvingRecords.first {
                    InfoCard(title: "Calving Details") {
                        if let calvingDate = calving.calvingDate {
                            InfoRow(label: "Calving Date", value: formatDate(calvingDate))

                            // Show days since calving
                            if let daysSince = daysSinceCalving(calvingDate) {
                                InfoRow(label: "Days Since Calving", value: "\(daysSince) day\(daysSince == 1 ? "" : "s")")
                            }
                        }

                        if calving.difficulty != nil {
                            InfoRow(label: "Calving Ease", value: calving.displayDifficulty)
                        }

                        if calving.veterinarianCalled {
                            Divider()
                            InfoRow(label: "Veterinarian Called", value: "Yes")
                            if let assistance = calving.assistanceProvided, !assistance.isEmpty {
                                InfoRow(label: "Assistance Provided", value: assistance)
                            }
                        }

                        // Gestation length
                        if let gestationDays = pregnancy.gestationDays {
                            Divider()
                            InfoRow(label: "Gestation Length", value: "\(gestationDays) days")
                        }

                        if let notes = calving.notes, !notes.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Calving Notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }

                        // Link to full calving record
                        Divider()
                        NavigationLink(destination: CalvingDetailView(calvingRecord: calving)) {
                            HStack {
                                Text("View Full Calving Record")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // AI Protocol or Notes
                if let notes = pregnancy.notes, !notes.isEmpty {
                    // Check if this is a pending breeding with AI protocol
                    if pregnancy.status == PregnancyStatus.pending.rawValue,
                       let aiProtocol = detectAIProtocol(from: notes) {
                        InfoCard(title: "AI Protocol Steps") {
                            AIProtocolStepsView(aiProtocol: aiProtocol, startDate: pregnancy.breedingStartDate ?? pregnancy.breedingDate)
                        }
                    } else {
                        InfoCard(title: "Notes") {
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }

                // Photos Section
                if !pregnancy.sortedPhotos.isEmpty {
                    InfoCard(title: "Photos") {
                        Text("\(pregnancy.sortedPhotos.count) photo\(pregnancy.sortedPhotos.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        // TODO: Photo gallery
                    }
                }

                // Delete Button
                Button(role: .destructive, action: { showingDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Pregnancy Record")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .padding()
        }
        .navigationTitle("Pregnancy Details")
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
            #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingRecordCalving) {
            RecordCalvingView(pregnancy: pregnancy)
        }
        .sheet(isPresented: $showingEdit) {
            EditPregnancyView(pregnancy: pregnancy)
        }
        .alert("Delete Pregnancy Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePregnancy()
            }
        } message: {
            Text("Are you sure you want to delete this pregnancy record? This action cannot be undone.")
        }
    }

    // MARK: - Delete Pregnancy

    private func deletePregnancy() {
        viewContext.delete(pregnancy)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Error deleting pregnancy: \(nsError), \(nsError.userInfo)")
        }
    }

    // MARK: - Helper Functions

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func daysSinceCalving(_ calvingDate: Date) -> Int? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calvingDate, to: Date())
        return components.day
    }
}

#Preview {
    NavigationView {
        PregnancyDetailView(pregnancy: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            cattle.tagNumber = "LHF-001"
            cattle.name = "Bessie"

            let bull = Cattle.create(in: context)
            bull.tagNumber = "LHF-B01"
            bull.name = "Thunder"
            bull.sex = CattleSex.bull.rawValue

            let pregnancy = PregnancyRecord.create(for: cattle, method: .natural, in: context)
            pregnancy.bull = bull
            pregnancy.status = PregnancyStatus.confirmed.rawValue
            pregnancy.breedingDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())
            pregnancy.breedingMethod = BreedingMethod.natural.rawValue
            pregnancy.expectedCalvingDate = Calendar.current.date(byAdding: .day, value: 183, to: pregnancy.breedingDate!)
            pregnancy.confirmedDate = Calendar.current.date(byAdding: .day, value: -70, to: Date())
            pregnancy.notes = "Pregnancy confirmed via ultrasound. Dam in good health."

            return pregnancy
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
