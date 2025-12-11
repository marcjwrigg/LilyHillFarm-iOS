//
//  RecordCalvingView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct RecordCalvingView: View {
    @ObservedObject var pregnancy: PregnancyRecord
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Calving Details
    @State private var calvingDate = Date()
    @State private var calvingDifficulty: CalvingEase = .unassisted
    @State private var veterinarian = ""
    @State private var calvingNotes = ""

    // Calf Details
    @State private var calfTagNumber = ""
    @State private var calfName = ""
    @State private var calfSex: CattleSex = .heifer
    @State private var calfProductionPath: ProductionPath = .beefFinishing
    @State private var birthWeight = ""
    @State private var recordBirthWeight = false
    @State private var calfColor = ""
    @State private var calfMarkings = ""

    // Validation
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // Dam and Sire Section
                Section("Parents") {
                    if let dam = pregnancy.cow {
                        HStack {
                            Text("Dam")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(dam.displayName)
                                .fontWeight(.medium)
                        }
                    }

                    if let sire = pregnancy.bull {
                        HStack {
                            Text("Sire")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(sire.displayName)
                                .fontWeight(.medium)
                        }
                    }
                }

                // Calving Details
                Section("Calving Details") {
                    DatePicker("Calving Date", selection: $calvingDate, displayedComponents: [.date])

                    Picker("Difficulty", selection: $calvingDifficulty) {
                        ForEach(CalvingEase.allCases) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }

                    TextField("Veterinarian (optional)", text: $veterinarian)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $calvingNotes)
                            .frame(minHeight: 80)
                    }
                }

                // Calf Details
                Section("Calf Information") {
                    TextField("Tag Number *", text: $calfTagNumber)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif

                    TextField("Name (optional)", text: $calfName)

                    Picker("Sex *", selection: $calfSex) {
                        Text("Heifer").tag(CattleSex.heifer)
                        Text("Bull").tag(CattleSex.bull)
                        Text("Steer").tag(CattleSex.steer)
                    }

                    Picker("Production Path", selection: $calfProductionPath) {
                        ForEach(ProductionPath.allCases) { path in
                            Text(path.displayName).tag(path)
                        }
                    }
                }

                // Physical Attributes
                Section("Physical Attributes (Optional)") {
                    Toggle("Record Birth Weight", isOn: $recordBirthWeight)

                    if recordBirthWeight {
                        HStack {
                            TextField("Weight", text: $birthWeight)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("lbs")
                                .foregroundColor(.secondary)
                        }
                    }

                    TextField("Color", text: $calfColor)
                    TextField("Markings", text: $calfMarkings)
                }

                // Breed Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Breed Information")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Calf will inherit breed from dam")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Record Calving")
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
                    Button("Save") {
                        recordCalving()
                    }
                }
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Record Calving

    private func recordCalving() {
        // Validation
        if calfTagNumber.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Calf tag number is required"
            showingValidationAlert = true
            return
        }

        // Check for duplicate tag number
        let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tagNumber == %@", calfTagNumber)

        do {
            let results = try viewContext.fetch(fetchRequest)
            if !results.isEmpty {
                validationMessage = "A cattle with tag number '\(calfTagNumber)' already exists"
                showingValidationAlert = true
                return
            }
        } catch {
            validationMessage = "Error checking tag number: \(error.localizedDescription)"
            showingValidationAlert = true
            return
        }

        // Validate birth weight if provided
        if recordBirthWeight {
            guard let _ = Decimal(string: birthWeight) else {
                validationMessage = "Invalid birth weight"
                showingValidationAlert = true
                return
            }
        }

        // Create the calf
        let calf = Cattle.create(in: viewContext)
        calf.tagNumber = calfTagNumber
        calf.name = calfName.isEmpty ? nil : calfName
        calf.sex = calfSex.rawValue
        calf.dateOfBirth = calvingDate
        calf.currentStage = CattleStage.calf.rawValue
        calf.currentStatus = CattleStatus.active.rawValue
        calf.cattleType = pregnancy.cow?.cattleType ?? "Beef"
        calf.productionPath = calfProductionPath.rawValue

        // Inherit breed from dam
        if let dam = pregnancy.cow {
            calf.breed = dam.breed
            calf.dam = dam
        }

        // Set sire
        calf.sire = pregnancy.bull

        // Physical attributes
        if !calfColor.isEmpty {
            calf.color = calfColor
        }
        if !calfMarkings.isEmpty {
            calf.markings = calfMarkings
        }
        if recordBirthWeight, let weightValue = Decimal(string: birthWeight) {
            calf.currentWeight = NSDecimalNumber(decimal: weightValue)
        }

        // Create calving record
        let calvingRecord = CalvingRecord.create(for: pregnancy.cow!, in: viewContext)
        calvingRecord.calvingDate = calvingDate
        calvingRecord.difficulty = calvingDifficulty.rawValue
        calvingRecord.calf = calf

        if !veterinarian.isEmpty {
            calvingRecord.assistanceProvided = veterinarian
            calvingRecord.veterinarianCalled = true
        }
        if !calvingNotes.isEmpty {
            calvingRecord.notes = calvingNotes
        }
        if recordBirthWeight, let weightValue = Decimal(string: birthWeight) {
            calvingRecord.calfBirthWeight = NSDecimalNumber(decimal: weightValue)
        }

        // Update pregnancy status to calved
        pregnancy.status = PregnancyStatus.calved.rawValue

        // Save
        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            validationMessage = "Failed to save calving record: \(nsError.localizedDescription)"
            showingValidationAlert = true
        }
    }
}

#Preview {
    RecordCalvingView(pregnancy: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-001"
        cattle.name = "Bessie"
        cattle.sex = CattleSex.cow.rawValue

        let bull = Cattle.create(in: context)
        bull.tagNumber = "LHF-B01"
        bull.name = "Thunder"
        bull.sex = CattleSex.bull.rawValue

        let pregnancy = PregnancyRecord.create(for: cattle, method: .natural, in: context)
        pregnancy.bull = bull
        pregnancy.status = PregnancyStatus.confirmed.rawValue
        pregnancy.breedingDate = Calendar.current.date(byAdding: .day, value: -283, to: Date())
        pregnancy.expectedCalvingDate = Date()

        return pregnancy
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
