//
//  BulkPregnancyCheckView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BulkPregnancyCheckView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Pregnancy Check Details
    @State private var checkDate = Date()
    @State private var confirmationMethod = ""
    @State private var veterinarian = ""
    @State private var notes = ""

    // Individual results for each animal
    @State private var individualResults: [NSManagedObjectID: PregnancyStatus] = [:]

    // For new pregnancies (cattle without existing records)
    @State private var newPregnancySelection: Set<NSManagedObjectID> = []
    @State private var estimatedBreedingDate = Date().addingTimeInterval(-60 * 24 * 60 * 60) // 60 days ago

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    // Cattle with pregnancy records
    var cattleWithPregnancies: [Cattle] {
        selectedCattle.filter {
            let sex = $0.sex ?? ""
            let hasPregn = $0.currentPregnancy != nil
            return hasPregn && (sex == CattleSex.cow.rawValue || sex == CattleSex.heifer.rawValue)
        }
    }

    var cattleWithoutPregnancies: [Cattle] {
        selectedCattle.filter {
            let sex = $0.sex ?? ""
            let hasPregn = $0.currentPregnancy == nil
            return !hasPregn && (sex == CattleSex.cow.rawValue || sex == CattleSex.heifer.rawValue)
        }
    }

    var nonBreedableCattle: [Cattle] {
        selectedCattle.filter {
            let sex = $0.sex ?? ""
            return sex != CattleSex.cow.rawValue && sex != CattleSex.heifer.rawValue
        }
    }

    var resultsCount: (confirmed: Int, open: Int) {
        var confirmed = 0
        var open = 0
        for (_, status) in individualResults {
            if status == .confirmed {
                confirmed += 1
            } else if status == .open {
                open += 1
            }
        }
        return (confirmed, open)
    }

    var body: some View {
        NavigationView {
            formContent
                .navigationTitle("Bulk Pregnancy Check")
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
                        Button("Update All") {
                            updatePregnancies()
                        }
                        .disabled(cattleWithPregnancies.isEmpty && newPregnancySelection.isEmpty)
                    }
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                .onAppear {
                    // Initialize results with current status
                    for cattle in cattleWithPregnancies {
                        if let pregnancy = cattle.currentPregnancy,
                           let status = PregnancyStatus(rawValue: pregnancy.status ?? "") {
                            individualResults[cattle.objectID] = status
                        }
                    }
                }
        }
    }

    private var formContent: some View {
        Form {
            summarySection
            checkInfoSection
            pregnancyResultsSection
            notesSection
            newPregnanciesSection
            nonBreedableSection
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                Image(systemName: "stethoscope")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selectedCattle.count) Animals Selected")
                        .font(.headline)
                    if cattleWithPregnancies.isEmpty && cattleWithoutPregnancies.isEmpty {
                        Text("No breedable animals selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        if !cattleWithPregnancies.isEmpty {
                            Text("\(cattleWithPregnancies.count) with existing pregnancies")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !cattleWithoutPregnancies.isEmpty {
                            Text("\(cattleWithoutPregnancies.count) without breeding records")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            resultsSummary
        }
    }

    @ViewBuilder
    private var resultsSummary: some View {
        let counts = resultsCount
        if counts.confirmed > 0 || counts.open > 0 || !newPregnancySelection.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if counts.confirmed > 0 {
                    Label("\(counts.confirmed) Confirmed (existing)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                if counts.open > 0 {
                    Label("\(counts.open) Open (not pregnant)", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if !newPregnancySelection.isEmpty {
                    Label("\(newPregnancySelection.count) New pregnancies to add", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private var checkInfoSection: some View {
        Section("Check Information") {
            DatePicker("Check Date", selection: $checkDate, displayedComponents: [.date])

            TextField("Confirmation Method", text: $confirmationMethod)
                #if os(iOS)
                .autocapitalization(.words)
                #endif

            TextField("Veterinarian (Optional)", text: $veterinarian)
        }
    }

    @ViewBuilder
    private var pregnancyResultsSection: some View {
        if !cattleWithPregnancies.isEmpty {
            Section("Pregnancy Results") {
                ForEach(cattleWithPregnancies, id: \.objectID) { cattle in
                    PregnancyCheckRow(
                        cattle: cattle,
                        individualResults: $individualResults,
                        formatDate: formatDate
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
    private var newPregnanciesSection: some View {
        if !cattleWithoutPregnancies.isEmpty {
            Section {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(cattleWithoutPregnancies.count) No Breeding Record")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Select animals found to be pregnant")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !newPregnancySelection.isEmpty {
                    Text("\(newPregnancySelection.count) selected to add as pregnant")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Section("Estimated Breeding Date (for new pregnancies)") {
                DatePicker("Breeding Date", selection: $estimatedBreedingDate, displayedComponents: [.date])

                Text("Expected calving: \(formatDate(Calendar.current.date(byAdding: .day, value: 283, to: estimatedBreedingDate) ?? estimatedBreedingDate))")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Section("Select Animals to Record as Pregnant") {
                ForEach(cattleWithoutPregnancies, id: \.objectID) { cattle in
                    Button(action: {
                        if newPregnancySelection.contains(cattle.objectID) {
                            newPregnancySelection.remove(cattle.objectID)
                        } else {
                            newPregnancySelection.insert(cattle.objectID)
                        }
                    }) {
                        HStack {
                            Image(systemName: newPregnancySelection.contains(cattle.objectID) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(newPregnancySelection.contains(cattle.objectID) ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cattle.displayName)
                                    .foregroundColor(.primary)
                                Text(cattle.tagNumber ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var nonBreedableSection: some View {
        if !nonBreedableCattle.isEmpty {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(nonBreedableCattle.count) Cannot Be Checked")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Only cows and heifers can be pregnancy checked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(nonBreedableCattle, id: \.objectID) { cattle in
                    HStack {
                        Text(cattle.displayName)
                        Spacer()
                        Text(cattle.sex ?? "Unknown")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Update Pregnancies

    private func updatePregnancies() {
        // Validation
        guard !confirmationMethod.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter confirmation method (e.g., Ultrasound, Palpation)"
            showingError = true
            return
        }

        // Update each pregnancy record
        for cattle in cattleWithPregnancies {
            guard let pregnancy = cattle.currentPregnancy,
                  let newStatus = individualResults[cattle.objectID] else {
                continue
            }

            pregnancy.status = newStatus.rawValue

            if newStatus == .confirmed {
                pregnancy.confirmedDate = checkDate
                pregnancy.confirmationMethod = confirmationMethod.trimmingCharacters(in: .whitespaces)
            }

            // Build notes with veterinarian info
            var fullNotes = ""
            if !veterinarian.isEmpty {
                fullNotes = "Veterinarian: \(veterinarian.trimmingCharacters(in: .whitespaces))"
            }
            if !notes.isEmpty {
                if !fullNotes.isEmpty {
                    fullNotes += "\n"
                }
                fullNotes += notes
            }
            if !fullNotes.isEmpty {
                pregnancy.notes = fullNotes
            }

            cattle.modifiedAt = Date()
        }

        // Create new pregnancy records for selected cattle without existing records
        for cattle in cattleWithoutPregnancies {
            guard newPregnancySelection.contains(cattle.objectID) else { continue }

            // Create new pregnancy record
            let pregnancy = PregnancyRecord.create(for: cattle, method: .natural, in: viewContext)
            pregnancy.breedingDate = estimatedBreedingDate
            pregnancy.expectedCalvingDate = Calendar.current.date(byAdding: .day, value: 283, to: estimatedBreedingDate)
            pregnancy.status = PregnancyStatus.confirmed.rawValue
            pregnancy.confirmedDate = checkDate
            pregnancy.confirmationMethod = confirmationMethod.trimmingCharacters(in: .whitespaces)

            // Build notes with veterinarian info
            var fullNotes = "Pregnancy discovered without prior breeding record. "
            if !veterinarian.isEmpty {
                fullNotes += "Veterinarian: \(veterinarian.trimmingCharacters(in: .whitespaces)). "
            }
            if !notes.isEmpty {
                fullNotes += notes
            }
            pregnancy.notes = fullNotes

            cattle.modifiedAt = Date()
        }

        // Save all changes
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
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

private struct PregnancyCheckRow: View {
    let cattle: Cattle
    @Binding var individualResults: [NSManagedObjectID: PregnancyStatus]
    let formatDate: (Date) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Animal Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cattle.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(cattle.tagNumber ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if let pregnancy = cattle.currentPregnancy {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let breedingDate = pregnancy.breedingDate {
                            Text("Bred: \(formatDate(breedingDate))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let expectedDate = pregnancy.expectedCalvingDate {
                            Text("Due: \(formatDate(expectedDate))")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }

            // Result Picker
            Picker("Result", selection: Binding(
                get: { individualResults[cattle.objectID] ?? .bred },
                set: { individualResults[cattle.objectID] = $0 }
            )) {
                Text("Bred").tag(PregnancyStatus.bred)
                Text("Confirmed").tag(PregnancyStatus.confirmed)
                Text("Open (Not Pregnant)").tag(PregnancyStatus.open)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BulkPregnancyCheckView(selectedCattle: {
        let context = PersistenceController.preview.container.viewContext
        var cattle: [Cattle] = []

        for i in 1...3 {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-C\(String(format: "%03d", i))"
            animal.name = "Cow \(i)"
            animal.sex = CattleSex.cow.rawValue

            // Add pregnancy record
            let pregnancy = PregnancyRecord.create(for: animal, method: .natural, in: context)
            pregnancy.breedingDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())
            pregnancy.expectedCalvingDate = Calendar.current.date(byAdding: .day, value: 223, to: Date())
            pregnancy.status = PregnancyStatus.bred.rawValue

            cattle.append(animal)
        }

        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
