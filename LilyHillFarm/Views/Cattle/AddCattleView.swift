//
//  AddCattleView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct AddCattleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Breed.name, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default)
    private var breeds: FetchedResults<Breed>

    // Basic Information
    @State private var tagNumber = ""
    @State private var name = ""
    @State private var selectedSex: CattleSex?
    @State private var selectedBreed: Breed?
    @State private var selectedType: CattleType = .beef
    @State private var color = ""
    @State private var markings = ""

    // Lifecycle
    @State private var selectedStage: CattleStage = .calf
    @State private var selectedPath: ProductionPath = .beefFinishing

    // Date
    @State private var hasDOB = false
    @State private var dateOfBirth = Date()
    @State private var approximateAge = ""

    // Weight
    @State private var hasWeight = false
    @State private var weight = ""

    // Notes
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Basic Information") {
                    TextField("Tag Number *", text: $tagNumber)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif

                    TextField("Name (Optional)", text: $name)

                    Picker("Sex *", selection: $selectedSex) {
                        Text("Select...").tag(nil as CattleSex?)
                        ForEach(CattleSex.allCases) { sex in
                            Text(sex.rawValue).tag(sex as CattleSex?)
                        }
                    }

                    Picker("Breed *", selection: $selectedBreed) {
                        Text("Select...").tag(nil as Breed?)
                        ForEach(breeds, id: \.objectID) { breed in
                            Text(breed.name ?? "Unknown").tag(breed as Breed?)
                        }
                    }

                    Picker("Type", selection: $selectedType) {
                        ForEach(CattleType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Color", text: $color)
                    TextField("Markings", text: $markings)
                }

                // Age Information
                Section("Age") {
                    Toggle("Known Date of Birth", isOn: $hasDOB)

                    if hasDOB {
                        DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    } else {
                        TextField("Approximate Age (e.g., '2 years')", text: $approximateAge)
                    }
                }

                // Lifecycle
                Section("Lifecycle") {
                    Picker("Current Stage", selection: $selectedStage) {
                        ForEach(CattleStage.allCases) { stage in
                            Text(stage.displayName).tag(stage)
                        }
                    }

                    Picker("Production Path", selection: $selectedPath) {
                        ForEach(ProductionPath.allCases) { path in
                            Text(path.displayName).tag(path)
                        }
                    }
                }

                // Weight
                Section("Physical Attributes") {
                    Toggle("Record Current Weight", isOn: $hasWeight)

                    if hasWeight {
                        HStack {
                            TextField("Weight", text: $weight)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("lbs")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Cattle")
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
                        saveCattle()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !tagNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedSex != nil &&
        selectedBreed != nil
    }

    // MARK: - Save

    private func saveCattle() {
        let cattle = Cattle.create(in: viewContext)

        // Basic info
        cattle.tagNumber = tagNumber.trimmingCharacters(in: .whitespaces)
        cattle.name = name.isEmpty ? nil : name
        cattle.sex = selectedSex?.rawValue
        cattle.breed = selectedBreed
        cattle.cattleType = selectedType.rawValue
        cattle.color = color.isEmpty ? nil : color
        cattle.markings = markings.isEmpty ? nil : markings

        // Age
        if hasDOB {
            cattle.dateOfBirth = dateOfBirth
        } else if !approximateAge.isEmpty {
            cattle.approximateAge = approximateAge
        }

        // Lifecycle
        cattle.currentStage = selectedStage.rawValue
        cattle.productionPath = selectedPath.rawValue

        // Weight
        if hasWeight, let weightValue = Decimal(string: weight) {
            cattle.currentWeight = NSDecimalNumber(decimal: weightValue)
        }

        // Notes
        if !notes.isEmpty {
            cattle.notes = notes
        }

        // Save
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save cattle: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    AddCattleView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
