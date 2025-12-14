//
//  BulkBreedingView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BulkBreedingView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Breeding Details (common to all)
    @State private var breedingDate = Date()
    @State private var breedingMethod: BreedingMethod = .natural
    @State private var selectedBull: Cattle?
    @State private var externalBullName = ""
    @State private var externalBullRegistration = ""
    @State private var semenSource = ""
    @State private var aiTechnician = ""
    @State private var notes = ""

    // Bulls available in herd
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "sex == %@ AND currentStatus == %@", CattleSex.bull.rawValue, CattleStatus.active.rawValue),
        animation: .default
    )
    private var bulls: FetchedResults<Cattle>

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    // Filter: Only show females that can be bred
    var breedableCattle: [Cattle] {
        selectedCattle.filter { cattle in
            let sex = cattle.sex ?? ""
            return sex == CattleSex.cow.rawValue || sex == CattleSex.heifer.rawValue
        }
    }

    var nonBreedableCattle: [Cattle] {
        selectedCattle.filter { cattle in
            let sex = cattle.sex ?? ""
            return sex != CattleSex.cow.rawValue && sex != CattleSex.heifer.rawValue
        }
    }

    var expectedCalvingDate: Date {
        Calendar.current.date(byAdding: .day, value: 283, to: breedingDate) ?? breedingDate
    }

    var body: some View {
        NavigationView {
            Form {
                // Selected Cattle Summary
                Section {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(breedableCattle.count) Females Selected")
                                .font(.headline)
                            Text("Record breeding/AI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Breeding Details
                Section("Breeding Information") {
                    DatePicker("Breeding Date", selection: $breedingDate, displayedComponents: [.date])

                    Picker("Method", selection: $breedingMethod) {
                        Text("Natural").tag(BreedingMethod.natural)
                        Text("AI").tag(BreedingMethod.artificialInsemination)
                        Text("Embryo Transfer").tag(BreedingMethod.embryoTransfer)
                    }

                    HStack {
                        Text("Expected Calving")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(expectedCalvingDate))
                            .foregroundColor(.blue)
                    }
                }

                // Bull Selection (Natural) or External Bull (AI/ET)
                if breedingMethod == .natural {
                    Section("Sire (Herd Bull)") {
                        if bulls.isEmpty {
                            Text("No bulls in herd")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            Picker("Bull", selection: $selectedBull) {
                                Text("Select Bull").tag(nil as Cattle?)
                                ForEach(Array(bulls), id: \.objectID) { bull in
                                    Text("\(bull.displayName) (\(bull.tagNumber ?? ""))").tag(bull as Cattle?)
                                }
                            }
                        }
                    }
                } else {
                    Section("Sire (External/AI)") {
                        TextField("Bull Name", text: $externalBullName)
                        TextField("Registration Number (Optional)", text: $externalBullRegistration)
                        TextField("Semen Source (Optional)", text: $semenSource)

                        if breedingMethod == .artificialInsemination {
                            TextField("AI Technician (Optional)", text: $aiTechnician)
                        }
                    }
                }

                // Notes
                Section("Notes (Applied to all)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                // Breedable Animals
                if !breedableCattle.isEmpty {
                    Section("Animals to Breed (\(breedableCattle.count))") {
                        ForEach(breedableCattle, id: \.objectID) { cattle in
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
                                if let stage = cattle.currentStage {
                                    Text(stage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Non-breedable animals
                if !nonBreedableCattle.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(nonBreedableCattle.count) Cannot Be Bred")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Only cows and heifers can be bred")
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
            .navigationTitle("Bulk Breeding")
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
                        recordBulkBreeding()
                    }
                    .disabled(breedableCattle.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Record Bulk Breeding

    private func recordBulkBreeding() {
        // Validation
        if breedingMethod == .natural {
            guard selectedBull != nil else {
                errorMessage = "Please select a bull from the herd"
                showingError = true
                return
            }
        } else {
            guard !externalBullName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Please enter the bull name"
                showingError = true
                return
            }
        }

        // Create pregnancy records for each breedable animal
        for cattle in breedableCattle {
            let pregnancy = PregnancyRecord.create(for: cattle, method: breedingMethod, in: viewContext)
            pregnancy.breedingDate = breedingDate

            if breedingMethod == .natural {
                pregnancy.bull = selectedBull
            } else {
                pregnancy.externalBullName = externalBullName.trimmingCharacters(in: .whitespaces)
                if !externalBullRegistration.isEmpty {
                    pregnancy.externalBullRegistration = externalBullRegistration.trimmingCharacters(in: .whitespaces)
                }
                if !semenSource.isEmpty {
                    pregnancy.semenSource = semenSource.trimmingCharacters(in: .whitespaces)
                }
                if !aiTechnician.isEmpty {
                    pregnancy.aiTechnician = aiTechnician.trimmingCharacters(in: .whitespaces)
                }
            }

            // Calculate expected calving date
            pregnancy.expectedCalvingDate = expectedCalvingDate

            // Set status as bred (needs confirmation)
            pregnancy.status = PregnancyStatus.bred.rawValue

            if !notes.isEmpty {
                pregnancy.notes = notes
            }

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
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    BulkBreedingView(selectedCattle: {
        let context = PersistenceController.preview.container.viewContext
        var cattle: [Cattle] = []

        for i in 1...3 {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-C\(String(format: "%03d", i))"
            animal.name = "Cow \(i)"
            animal.sex = CattleSex.cow.rawValue
            animal.currentStage = LegacyCattleStage.breeding.rawValue
            cattle.append(animal)
        }

        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
