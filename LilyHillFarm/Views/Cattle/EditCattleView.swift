//
//  EditCattleView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct EditCattleView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Breed.name, ascending: true)],
        animation: .default)
    private var breeds: FetchedResults<Breed>

    // State variables
    @State private var tagNumber = ""
    @State private var name = ""
    @State private var selectedSex: CattleSex?
    @State private var selectedBreed: Breed?
    @State private var selectedType: CattleType = .beef
    @State private var color = ""
    @State private var markings = ""
    @State private var selectedStage: CattleStage = .calf
    @State private var selectedPath: ProductionPath = .beefFinishing
    @State private var hasDOB = false
    @State private var dateOfBirth = Date()
    @State private var approximateAge = ""
    @State private var hasWeight = false
    @State private var weight = ""
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    // Delete confirmation
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            Form {
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

                    Picker("Breed", selection: $selectedBreed) {
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

                Section("Age") {
                    Toggle("Known Date of Birth", isOn: $hasDOB)

                    if hasDOB {
                        DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    } else {
                        TextField("Approximate Age", text: $approximateAge)
                    }
                }

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

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Animal", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Cattle")
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
            .confirmationDialog("Delete Animal", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteCattle()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(cattle.tagNumber ?? "this animal")? This action cannot be undone.")
            }
            .onAppear {
                loadCattleData()
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !tagNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedSex != nil
    }

    // MARK: - Load Data

    private func loadCattleData() {
        tagNumber = cattle.tagNumber ?? ""
        name = cattle.name ?? ""
        selectedSex = CattleSex(rawValue: cattle.sex ?? "")
        selectedBreed = cattle.breed
        selectedType = CattleType(rawValue: cattle.cattleType ?? "") ?? .beef
        color = cattle.color ?? ""
        markings = cattle.markings ?? ""
        selectedStage = CattleStage(rawValue: cattle.currentStage ?? "") ?? .calf
        selectedPath = ProductionPath(rawValue: cattle.productionPath ?? "") ?? .beefFinishing

        if let dob = cattle.dateOfBirth {
            hasDOB = true
            dateOfBirth = dob
        } else {
            hasDOB = false
            approximateAge = cattle.approximateAge ?? ""
        }

        if let currentWeight = cattle.currentWeight as? Decimal, currentWeight > 0 {
            hasWeight = true
            weight = "\(currentWeight)"
        }

        notes = cattle.notes ?? ""
    }

    // MARK: - Delete

    private func deleteCattle() {
        cattle.deletedAt = Date()

        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to delete animal: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Save

    private func saveCattle() {
        // Update basic info
        cattle.tagNumber = tagNumber.trimmingCharacters(in: .whitespaces)
        cattle.name = name.isEmpty ? nil : name
        cattle.sex = selectedSex?.rawValue
        cattle.breed = selectedBreed
        cattle.cattleType = selectedType.rawValue
        cattle.color = color.isEmpty ? nil : color
        cattle.markings = markings.isEmpty ? nil : markings

        // Update lifecycle
        cattle.currentStage = selectedStage.rawValue
        cattle.productionPath = selectedPath.rawValue

        // Update age
        if hasDOB {
            cattle.dateOfBirth = dateOfBirth
            cattle.approximateAge = nil
        } else {
            cattle.dateOfBirth = nil
            cattle.approximateAge = approximateAge.isEmpty ? nil : approximateAge
        }

        // Update weight
        if hasWeight, let weightValue = Decimal(string: weight) {
            cattle.currentWeight = NSDecimalNumber(decimal: weightValue)
        } else if !hasWeight {
            cattle.currentWeight = nil
        }

        // Update notes
        cattle.notes = notes.isEmpty ? nil : notes

        // Update modified date
        cattle.modifiedAt = Date()

        // Save
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    EditCattleView(cattle: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-001"
        cattle.name = "Bessie"
        cattle.sex = CattleSex.cow.rawValue
        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
