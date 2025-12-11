//
//  BulkCalvingView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BulkCalvingView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Common Calving Details
    @State private var calvingDate = Date()
    @State private var veterinarianCalled = false
    @State private var veterinarian = ""
    @State private var notes = ""

    // Individual details for each cow
    @State private var individualCalfSex: [NSManagedObjectID: String] = [:]
    @State private var individualCalfWeight: [NSManagedObjectID: String] = [:]
    @State private var individualDifficulty: [NSManagedObjectID: CalvingEase] = [:]
    @State private var individualCalfStatus: [NSManagedObjectID: String] = [:]

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    // Cattle with pregnancies (can record calving)
    var cattleWithPregnancies: [Cattle] {
        selectedCattle.filter { cattle in
            let hasPregn = cattle.currentPregnancy != nil
            let sex = cattle.sex ?? ""
            return hasPregn && (sex == CattleSex.cow.rawValue || sex == CattleSex.heifer.rawValue)
        }
    }

    var cattleWithoutPregnancies: [Cattle] {
        selectedCattle.filter { cattle in
            let hasPregn = cattle.currentPregnancy != nil
            let sex = cattle.sex ?? ""
            return !hasPregn || (sex != CattleSex.cow.rawValue && sex != CattleSex.heifer.rawValue)
        }
    }

    var body: some View {
        NavigationView {
            formContent
                .navigationTitle("Bulk Calving")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Record All") {
                            recordCalvings()
                        }
                        .disabled(cattleWithPregnancies.isEmpty)
                    }
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                .onAppear {
                    // Initialize defaults
                    for cattle in cattleWithPregnancies {
                        individualDifficulty[cattle.objectID] = .unassisted
                        individualCalfStatus[cattle.objectID] = "Alive"
                    }
                }
        }
    }

    private var formContent: some View {
        Form {
            summarySection
            calvingInfoSection
            individualDetailsSection
            notesSection
            noPregnanciSection
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                Image(systemName: "figure.and.child.holdinghands")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(cattleWithPregnancies.count) Calvings to Record")
                        .font(.headline)
                    Text("Enter calving details for each")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var calvingInfoSection: some View {
        Section("Calving Information") {
            DatePicker("Calving Date", selection: $calvingDate, displayedComponents: [.date])

            Toggle("Veterinarian Called", isOn: $veterinarianCalled)

            if veterinarianCalled {
                TextField("Veterinarian Name", text: $veterinarian)
            }
        }
    }

    @ViewBuilder
    private var individualDetailsSection: some View {
        if !cattleWithPregnancies.isEmpty {
            Section("Calving Details for Each Cow") {
                ForEach(cattleWithPregnancies, id: \.objectID) { cattle in
                    CattleCalvingDetailRow(
                        cattle: cattle,
                        calvingDate: calvingDate,
                        individualCalfSex: $individualCalfSex,
                        individualCalfWeight: $individualCalfWeight,
                        individualDifficulty: $individualDifficulty,
                        individualCalfStatus: $individualCalfStatus
                    )
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes (Applied to all)") {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        }
    }

    @ViewBuilder
    private var noPregnanciSection: some View {
        if !cattleWithoutPregnancies.isEmpty {
            Section {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(cattleWithoutPregnancies.count) No Pregnancy Record")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("These animals don't have an active pregnancy record")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(cattleWithoutPregnancies, id: \.objectID) { cattle in
                    HStack {
                        Text(cattle.displayName)
                        Spacer()
                        Text(cattle.tagNumber ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Record Calvings

    private func recordCalvings() {
        // Validation
        for cattle in cattleWithPregnancies {
            // Check calf sex
            if let sex = individualCalfSex[cattle.objectID], sex.isEmpty {
                errorMessage = "Please select calf sex for \(cattle.displayName)"
                showingError = true
                return
            }

            // Check weight
            if let weightString = individualCalfWeight[cattle.objectID], !weightString.isEmpty {
                guard Decimal(string: weightString) != nil else {
                    errorMessage = "Invalid calf weight for \(cattle.displayName)"
                    showingError = true
                    return
                }
            }
        }

        // Create calving records
        for cattle in cattleWithPregnancies {
            guard let pregnancy = cattle.currentPregnancy else { continue }

            let calvingRecord = CalvingRecord.create(for: cattle, in: viewContext)
            calvingRecord.calvingDate = calvingDate
            calvingRecord.dam = cattle
            calvingRecord.sire = pregnancy.bull

            if let calfSex = individualCalfSex[cattle.objectID], !calfSex.isEmpty {
                calvingRecord.calfSex = calfSex
            }

            if let weightString = individualCalfWeight[cattle.objectID],
               let weight = Decimal(string: weightString) {
                calvingRecord.calfBirthWeight = NSDecimalNumber(decimal: weight)
            }

            if let difficulty = individualDifficulty[cattle.objectID] {
                calvingRecord.difficulty = difficulty.rawValue
            }

            // Note: calfStatus removed from CalvingRecord Core Data model
            // if let status = individualCalfStatus[cattle.objectID] {
            //     calvingRecord.calfStatus = status
            // }

            calvingRecord.veterinarianCalled = veterinarianCalled
            if veterinarianCalled && !veterinarian.isEmpty {
                calvingRecord.assistanceProvided = "Veterinarian: \(veterinarian.trimmingCharacters(in: .whitespaces))"
            }

            if !notes.isEmpty {
                calvingRecord.notes = notes
            }

            // Close the pregnancy record
            pregnancy.status = PregnancyStatus.calved.rawValue

            // If heifer (by sex) gave birth, they continue in breeding stage
            // No stage change needed as they're already in appropriate stage for breeding animals

            cattle.modifiedAt = Date()
        }

        // Save all records
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save records: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views

private struct CattleCalvingDetailRow: View {
    let cattle: Cattle
    let calvingDate: Date
    @Binding var individualCalfSex: [NSManagedObjectID: String]
    @Binding var individualCalfWeight: [NSManagedObjectID: String]
    @Binding var individualDifficulty: [NSManagedObjectID: CalvingEase]
    @Binding var individualCalfStatus: [NSManagedObjectID: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cow Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cattle.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(cattle.tagNumber ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if let pregnancy = cattle.currentPregnancy,
                   let expectedDate = pregnancy.expectedCalvingDate {
                    DueDateView(expectedDate: expectedDate, calvingDate: calvingDate)
                }
            }

            Divider()

            calfSexPicker
            calfWeightField
            difficultyPicker
            calfStatusButtons

            Divider()
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private var calfSexPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calf Sex")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("Calf Sex", selection: Binding(
                get: { individualCalfSex[cattle.objectID] ?? "" },
                set: { individualCalfSex[cattle.objectID] = $0 }
            )) {
                Text("Select...").tag("")
                Text("Bull").tag(CattleSex.bull.rawValue)
                Text("Heifer").tag(CattleSex.heifer.rawValue)
            }
            .pickerStyle(.segmented)
        }
    }

    private var calfWeightField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calf Birth Weight")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                TextField("Weight", text: Binding(
                    get: { individualCalfWeight[cattle.objectID] ?? "" },
                    set: { individualCalfWeight[cattle.objectID] = $0 }
                ))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                Text("lbs")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calving Difficulty")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("Difficulty", selection: Binding(
                get: { individualDifficulty[cattle.objectID] ?? .unassisted },
                set: { individualDifficulty[cattle.objectID] = $0 }
            )) {
                Text("Unassisted").tag(CalvingEase.unassisted)
                Text("Easy Pull").tag(CalvingEase.easyPull)
                Text("Hard Pull").tag(CalvingEase.hardPull)
                Text("Caesarean").tag(CalvingEase.caesarean)
            }
            .pickerStyle(.segmented)
        }
    }

    private var calfStatusButtons: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calf Status")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button(action: {
                    individualCalfStatus[cattle.objectID] = "Alive"
                }) {
                    HStack {
                        Image(systemName: individualCalfStatus[cattle.objectID] == "Alive" ? "checkmark.circle.fill" : "circle")
                        Text("Alive")
                    }
                    .foregroundColor(individualCalfStatus[cattle.objectID] == "Alive" ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    individualCalfStatus[cattle.objectID] = "Stillborn"
                }) {
                    HStack {
                        Image(systemName: individualCalfStatus[cattle.objectID] == "Stillborn" ? "checkmark.circle.fill" : "circle")
                        Text("Stillborn")
                    }
                    .foregroundColor(individualCalfStatus[cattle.objectID] == "Stillborn" ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DueDateView: View {
    let expectedDate: Date
    let calvingDate: Date

    private var daysDiff: Int {
        Calendar.current.dateComponents([.day], from: expectedDate, to: calvingDate).day ?? 0
    }

    private var formattedExpectedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: expectedDate)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Due: \(formattedExpectedDate)")
                .font(.caption2)
                .foregroundColor(.blue)

            if daysDiff != 0 {
                Text("\(daysDiff > 0 ? "+" : "")\(daysDiff) days")
                    .font(.caption2)
                    .foregroundColor(daysDiff > 0 ? .orange : .green)
            }
        }
    }
}

#Preview {
    BulkCalvingView(selectedCattle: {
        let context = PersistenceController.preview.container.viewContext
        var cattle: [Cattle] = []

        for i in 1...2 {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-C\(String(format: "%03d", i))"
            animal.name = "Cow \(i)"
            animal.sex = CattleSex.cow.rawValue

            // Add pregnancy record
            let pregnancy = PregnancyRecord.create(for: animal, method: .natural, in: context)
            pregnancy.breedingDate = Calendar.current.date(byAdding: .day, value: -280, to: Date())
            pregnancy.expectedCalvingDate = Date()
            pregnancy.status = PregnancyStatus.confirmed.rawValue

            cattle.append(animal)
        }

        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
