//
//  CalvingDetailView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct CalvingDetailView: View {
    @ObservedObject var calvingRecord: CalvingRecord
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    // Fetch pregnancy record for this calving
    @FetchRequest private var pregnancyRecords: FetchedResults<PregnancyRecord>

    init(calvingRecord: CalvingRecord) {
        self.calvingRecord = calvingRecord

        // Fetch pregnancy record for this calving
        _pregnancyRecords = FetchRequest<PregnancyRecord>(
            sortDescriptors: [],
            predicate: calvingRecord.pregnancyId != nil
                ? NSPredicate(format: "id == %@", calvingRecord.pregnancyId! as CVarArg)
                : NSPredicate(value: false)
        )
    }

    var difficultyColor: Color {
        guard let difficulty = CalvingEase(rawValue: calvingRecord.difficulty ?? "") else {
            return .gray
        }

        switch difficulty {
        case .unassisted:
            return .green
        case .easyPull:
            return .orange
        case .hardPull:
            return .red
        case .caesarean:
            return .purple
        case .other:
            return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Calving Record")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Show calving date
                    if let calvingDate = calvingRecord.calvingDate {
                        Text("Calved: \(formatDate(calvingDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Show days since calving
                        if let daysSince = daysSinceCalving(calvingDate) {
                            Text("\(daysSince) day\(daysSince == 1 ? "" : "s") ago")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Date not recorded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Difficulty Badge
                    HStack {
                        Image(systemName: "staroflife.circle.fill")
                            .foregroundColor(difficultyColor)
                        Text(calvingRecord.displayDifficulty)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(difficultyColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.top)

                // Calf Information
                if let calf = calvingRecord.calf {
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

                        if let weight = calvingRecord.calfBirthWeight as? Decimal, weight > 0 {
                            InfoRow(label: "Birth Weight", value: "\(weight as NSNumber) lbs")
                        }

                        if let sex = calf.sex {
                            InfoRow(label: "Sex", value: sex)
                        }

                        InfoRow(label: "Current Age", value: calf.age)
                    }
                }

                // Dam Information
                if let dam = calvingRecord.dam {
                    InfoCard(title: "Dam") {
                        NavigationLink(destination: CattleDetailView(cattle: dam)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dam.displayName)
                                        .font(.headline)
                                    Text(dam.tagNumber ?? "No Tag")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let breed = dam.breed?.name {
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
                    }
                }

                // Sire Information
                if let calf = calvingRecord.calf {
                    if let sire = calf.sire {
                        // Internal bull
                        InfoCard(title: "Sire") {
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
                        }
                    } else if let externalSireName = calf.externalSireName, !externalSireName.isEmpty {
                        // AI bull (external)
                        InfoCard(title: "Sire") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(externalSireName)
                                    .font(.headline)
                                Text("AI Bull")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let registration = calf.externalSireRegistration, !registration.isEmpty {
                                    Text("Reg: \(registration)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Breeding Details (from pregnancy record)
                if let pregnancy = pregnancyRecords.first {
                    InfoCard(title: "Breeding Details") {
                        // Breeding date and method
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
                        } else if let breedingDate = pregnancy.breedingDate {
                            InfoRow(label: "Breeding Date", value: formatDate(breedingDate))
                        }

                        if let method = pregnancy.breedingMethod {
                            InfoRow(label: "Method", value: method)
                        }

                        // AI details
                        if let aiTech = pregnancy.aiTechnician, !aiTech.isEmpty {
                            InfoRow(label: "AI Technician", value: aiTech)
                        }

                        if let semenSource = pregnancy.semenSource, !semenSource.isEmpty {
                            InfoRow(label: "Semen Source", value: semenSource)
                        }

                        // Sire registration
                        if let externalBullReg = pregnancy.externalBullRegistration, !externalBullReg.isEmpty {
                            InfoRow(label: "Sire Registration", value: externalBullReg)
                        }

                        // Pregnancy confirmation
                        if let confirmedDate = pregnancy.confirmedDate {
                            Divider()
                            InfoRow(label: "Pregnancy Confirmed", value: formatDate(confirmedDate))
                            if let confirmMethod = pregnancy.confirmationMethod {
                                InfoRow(label: "Confirmation Method", value: confirmMethod)
                            }
                        }

                        // Gestation length
                        if let gestationDays = pregnancy.gestationDays {
                            Divider()
                            InfoRow(label: "Gestation Length", value: "\(gestationDays) days")
                        }

                        // Pregnancy notes
                        if let notes = pregnancy.notes, !notes.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pregnancy Notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                // Calving Details
                InfoCard(title: "Calving Details") {
                    InfoRow(label: "Date", value: calvingRecord.displayDate)
                    InfoRow(label: "Difficulty", value: calvingRecord.displayDifficulty)

                    if calvingRecord.veterinarianCalled {
                        InfoRow(label: "Veterinarian Called", value: "Yes")
                        if let assistance = calvingRecord.assistanceProvided, !assistance.isEmpty {
                            InfoRow(label: "Assistance Provided", value: assistance)
                        }
                    }
                }

                // Notes
                if let notes = calvingRecord.notes, !notes.isEmpty {
                    InfoCard(title: "Notes") {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }

                // Photos Section
                if !calvingRecord.sortedPhotos.isEmpty {
                    InfoCard(title: "Photos") {
                        Text("\(calvingRecord.sortedPhotos.count) photo\(calvingRecord.sortedPhotos.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        // TODO: Photo gallery
                    }
                }

                // Delete Button
                Button(role: .destructive, action: { showingDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Calving Record")
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
        .navigationTitle("Calving Details")
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
            #endif
        .alert("Delete Calving Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCalvingRecord()
            }
        } message: {
            Text("Are you sure you want to delete this calving record? The calf will not be deleted.")
        }
    }

    // MARK: - Delete Calving Record

    private func deleteCalvingRecord() {
        viewContext.delete(calvingRecord)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Error deleting calving record: \(nsError), \(nsError.userInfo)")
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
        CalvingDetailView(calvingRecord: {
            let context = PersistenceController.preview.container.viewContext

            let dam = Cattle.create(in: context)
            dam.tagNumber = "LHF-001"
            dam.name = "Bessie"
            dam.sex = CattleSex.cow.rawValue

            let sire = Cattle.create(in: context)
            sire.tagNumber = "LHF-B01"
            sire.name = "Thunder"
            sire.sex = CattleSex.bull.rawValue

            let calf = Cattle.create(in: context)
            calf.tagNumber = "LHF-C001"
            calf.name = "Junior"
            calf.sex = CattleSex.bull.rawValue
            calf.dateOfBirth = Date()
            calf.dam = dam
            calf.sire = sire
            calf.currentStage = LegacyCattleStage.calf.rawValue

            let calving = CalvingRecord.create(for: dam, in: context)
            calving.calvingDate = Date()
            calving.difficulty = CalvingEase.unassisted.rawValue
            calving.calf = calf
            calving.calfBirthWeight = NSDecimalNumber(value: 85)
            calving.assistanceProvided = "Dr. Smith"
            calving.veterinarianCalled = true
            calving.notes = "Healthy calf, no complications"

            return calving
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
