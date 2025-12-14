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

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Veterinarian.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var veterinarians: FetchedResults<Veterinarian>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ProductionPath.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var productionPaths: FetchedResults<ProductionPath>

    // Calving Details
    @State private var calvingDate = Date()
    @State private var calvingDifficulty: CalvingEase = .unassisted
    @State private var selectedVeterinarian: Veterinarian?
    @State private var veterinaryAssistance = false
    @State private var damCondition = ""
    @State private var calvingNotes = ""

    // Calf 1 Details
    @State private var calfAlive = true
    @State private var calfTagNumber = ""
    @State private var calfName = ""
    @State private var calfSex: CattleSex = .heifer
    @State private var calfProductionPath: ProductionPath?
    @State private var birthWeight = ""
    @State private var recordBirthWeight = false
    @State private var calfColor = ""
    @State private var calfMarkings = ""

    // Twins Support
    @State private var twins = false
    @State private var calf2Alive = true
    @State private var calf2TagNumber = ""
    @State private var calf2Name = ""
    @State private var calf2Sex: CattleSex = .heifer
    @State private var calf2ProductionPath: ProductionPath?
    @State private var calf2BirthWeight = ""
    @State private var recordCalf2BirthWeight = false
    @State private var calf2Color = ""
    @State private var calf2Markings = ""

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

                    TextField("Dam Condition After Calving", text: $damCondition)
                        .autocorrectionDisabled()

                    Toggle("Veterinary Assistance Required", isOn: $veterinaryAssistance)
                        .tint(.blue)

                    if veterinaryAssistance {
                        Picker("Veterinarian", selection: $selectedVeterinarian) {
                            Text("Select...").tag(nil as Veterinarian?)
                            ForEach(veterinarians) { vet in
                                Text(vet.displayValue).tag(vet as Veterinarian?)
                            }
                        }
                    }

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
                    Toggle("Calf Born Alive", isOn: $calfAlive)
                        .tint(.green)

                    TextField("Tag Number *", text: $calfTagNumber)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif

                    TextField("Name (optional)", text: $calfName)
                        .disabled(!calfAlive)

                    Picker("Sex *", selection: $calfSex) {
                        Text("Heifer").tag(CattleSex.heifer)
                        Text("Bull").tag(CattleSex.bull)
                        Text("Steer").tag(CattleSex.steer)
                    }

                    Picker("Production Path", selection: $calfProductionPath) {
                        Text("Select Path").tag(nil as ProductionPath?)
                        ForEach(productionPaths) { path in
                            Text(path.displayValue).tag(path as ProductionPath?)
                        }
                    }
                    .disabled(!calfAlive)
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
                        .disabled(!calfAlive)
                    TextField("Markings", text: $calfMarkings)
                        .disabled(!calfAlive)
                }

                // Twins Section
                Section {
                    Toggle("Twins", isOn: $twins)
                        .tint(.orange)
                } footer: {
                    if twins {
                        Text("Enable this to record a second calf")
                    }
                }

                // Second Calf Details (shown when twins is enabled)
                if twins {
                    Section("Second Calf (Twin)") {
                        Toggle("Second Calf Born Alive", isOn: $calf2Alive)
                            .tint(.green)

                        TextField("Tag Number *", text: $calf2TagNumber)
                            #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            #endif

                        TextField("Name (optional)", text: $calf2Name)
                            .disabled(!calf2Alive)

                        Picker("Sex *", selection: $calf2Sex) {
                            Text("Heifer").tag(CattleSex.heifer)
                            Text("Bull").tag(CattleSex.bull)
                            Text("Steer").tag(CattleSex.steer)
                        }

                        Picker("Production Path", selection: $calf2ProductionPath) {
                            Text("Select Path").tag(nil as ProductionPath?)
                            ForEach(productionPaths) { path in
                                Text(path.displayValue).tag(path as ProductionPath?)
                            }
                        }
                        .disabled(!calf2Alive)
                    }

                    Section("Second Calf Physical Attributes (Optional)") {
                        Toggle("Record Birth Weight", isOn: $recordCalf2BirthWeight)

                        if recordCalf2BirthWeight {
                            HStack {
                                TextField("Weight", text: $calf2BirthWeight)
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                                Text("lbs")
                                    .foregroundColor(.secondary)
                            }
                        }

                        TextField("Color", text: $calf2Color)
                            .disabled(!calf2Alive)
                        TextField("Markings", text: $calf2Markings)
                            .disabled(!calf2Alive)
                    }
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
                            Text(twins ? "Calves will inherit breed from dam" : "Calf will inherit breed from dam")
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

        // Validate twins
        if twins && calf2TagNumber.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Second calf tag number is required for twins"
            showingValidationAlert = true
            return
        }

        // Check for duplicate tag numbers
        let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
        let tagsToCheck = twins ? [calfTagNumber, calf2TagNumber] : [calfTagNumber]

        for tag in tagsToCheck {
            fetchRequest.predicate = NSPredicate(format: "tagNumber == %@", tag)

            do {
                let results = try viewContext.fetch(fetchRequest)
                if !results.isEmpty {
                    validationMessage = "A cattle with tag number '\(tag)' already exists"
                    showingValidationAlert = true
                    return
                }
            } catch {
                validationMessage = "Error checking tag number: \(error.localizedDescription)"
                showingValidationAlert = true
                return
            }
        }

        // Validate birth weight if provided
        if recordBirthWeight {
            guard let _ = Decimal(string: birthWeight) else {
                validationMessage = "Invalid birth weight"
                showingValidationAlert = true
                return
            }
        }

        if twins && recordCalf2BirthWeight {
            guard let _ = Decimal(string: calf2BirthWeight) else {
                validationMessage = "Invalid birth weight for second calf"
                showingValidationAlert = true
                return
            }
        }

        // Create first calf (if alive)
        var calf: Cattle?
        if calfAlive {
            let newCalf = Cattle.create(in: viewContext)
            newCalf.tagNumber = calfTagNumber
            newCalf.name = calfName.isEmpty ? nil : calfName
            newCalf.sex = calfSex.rawValue
            newCalf.dateOfBirth = calvingDate
            newCalf.currentStage = "Calf"
            newCalf.currentStatus = CattleStatus.active.rawValue
            newCalf.cattleType = pregnancy.cow?.cattleType ?? "Beef"
            newCalf.productionPath = calfProductionPath?.name ?? "BeefFinishing"

            // Inherit breed from dam
            if let dam = pregnancy.cow {
                newCalf.breed = dam.breed
                newCalf.dam = dam
            }

            // Set sire (internal bull or external AI bull)
            if let bull = pregnancy.bull {
                newCalf.sire = bull
            } else if let externalBullName = pregnancy.externalBullName, !externalBullName.isEmpty {
                // AI bull - set external sire info
                newCalf.externalSireName = externalBullName
                newCalf.externalSireRegistration = pregnancy.externalBullRegistration
            }

            // Physical attributes
            if !calfColor.isEmpty {
                newCalf.color = calfColor
            }
            if !calfMarkings.isEmpty {
                newCalf.markings = calfMarkings
            }
            if recordBirthWeight, let weightValue = Decimal(string: birthWeight) {
                newCalf.currentWeight = NSDecimalNumber(decimal: weightValue)
            }

            calf = newCalf
        }

        // Create first calving record
        let calvingRecord = CalvingRecord.create(for: pregnancy.cow!, in: viewContext)
        calvingRecord.calvingDate = calvingDate
        calvingRecord.difficulty = calvingDifficulty.rawValue
        calvingRecord.calf = calf
        calvingRecord.calfSex = calfSex.rawValue
        calvingRecord.calfVigor = calfAlive ? "Good" : "Stillborn"

        if !damCondition.isEmpty {
            calvingRecord.complications = damCondition
        }
        if veterinaryAssistance {
            calvingRecord.veterinarianCalled = true
            // Save veterinarian ID and name
            calvingRecord.veterinarianId = selectedVeterinarian?.id
            calvingRecord.veterinarian = selectedVeterinarian?.name
            if let vetName = selectedVeterinarian?.name {
                calvingRecord.assistanceProvided = vetName
            }
        }
        if !calvingNotes.isEmpty {
            calvingRecord.notes = calvingNotes
        }
        if recordBirthWeight, let weightValue = Decimal(string: birthWeight) {
            calvingRecord.calfBirthWeight = NSDecimalNumber(decimal: weightValue)
        }

        // Link to pregnancy
        calvingRecord.pregnancyId = pregnancy.id

        // Create second calf and calving record if twins
        if twins {
            var calf2: Cattle?
            if calf2Alive {
                let newCalf2 = Cattle.create(in: viewContext)
                newCalf2.tagNumber = calf2TagNumber
                newCalf2.name = calf2Name.isEmpty ? nil : calf2Name
                newCalf2.sex = calf2Sex.rawValue
                newCalf2.dateOfBirth = calvingDate
                newCalf2.currentStage = "Calf"
                newCalf2.currentStatus = CattleStatus.active.rawValue
                newCalf2.cattleType = pregnancy.cow?.cattleType ?? "Beef"
                newCalf2.productionPath = calf2ProductionPath?.name ?? "BeefFinishing"

                // Inherit breed from dam
                if let dam = pregnancy.cow {
                    newCalf2.breed = dam.breed
                    newCalf2.dam = dam
                }

                // Set sire (same as first calf)
                if let bull = pregnancy.bull {
                    newCalf2.sire = bull
                } else if let externalBullName = pregnancy.externalBullName, !externalBullName.isEmpty {
                    newCalf2.externalSireName = externalBullName
                    newCalf2.externalSireRegistration = pregnancy.externalBullRegistration
                }

                // Physical attributes
                if !calf2Color.isEmpty {
                    newCalf2.color = calf2Color
                }
                if !calf2Markings.isEmpty {
                    newCalf2.markings = calf2Markings
                }
                if recordCalf2BirthWeight, let weightValue = Decimal(string: calf2BirthWeight) {
                    newCalf2.currentWeight = NSDecimalNumber(decimal: weightValue)
                }

                calf2 = newCalf2
            }

            // Create second calving record
            let calvingRecord2 = CalvingRecord.create(for: pregnancy.cow!, in: viewContext)
            calvingRecord2.calvingDate = calvingDate
            calvingRecord2.difficulty = calvingDifficulty.rawValue
            calvingRecord2.calf = calf2
            calvingRecord2.calfSex = calf2Sex.rawValue
            calvingRecord2.calfVigor = calf2Alive ? "Good" : "Stillborn"

            if !damCondition.isEmpty {
                calvingRecord2.complications = damCondition
            }
            if veterinaryAssistance {
                calvingRecord2.veterinarianCalled = true
                // Save veterinarian ID and name
                calvingRecord2.veterinarianId = selectedVeterinarian?.id
                calvingRecord2.veterinarian = selectedVeterinarian?.name
                if let vetName = selectedVeterinarian?.name {
                    calvingRecord2.assistanceProvided = vetName
                }
            }
            let twinNotes = calvingNotes.isEmpty ? "Twin 2" : "\(calvingNotes) (Twin 2)"
            calvingRecord2.notes = twinNotes

            if recordCalf2BirthWeight, let weightValue = Decimal(string: calf2BirthWeight) {
                calvingRecord2.calfBirthWeight = NSDecimalNumber(decimal: weightValue)
            }

            // Link to pregnancy
            calvingRecord2.pregnancyId = pregnancy.id
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
