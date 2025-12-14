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
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default)
    private var breeds: FetchedResults<Breed>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil AND sex IN %@", ["Bull"]),
        animation: .default)
    private var bulls: FetchedResults<Cattle>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil AND sex IN %@", ["Cow", "Heifer"]),
        animation: .default)
    private var cows: FetchedResults<Cattle>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CattleStage.sortOrder, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var cattleStages: FetchedResults<CattleStage>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ProductionPath.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var productionPaths: FetchedResults<ProductionPath>

    // State variables
    @State private var tagNumber = ""
    @State private var name = ""
    @State private var selectedSex: CattleSex?
    @State private var selectedBreed: Breed?
    @State private var selectedType: CattleType = .beef
    @State private var color = ""
    @State private var markings = ""
    @State private var selectedStatus: CattleStatus = .active
    @State private var tags = ""
    @State private var selectedStage: CattleStage?
    @State private var selectedPath: ProductionPath?
    @State private var hasDOB = false
    @State private var dateOfBirth = Date()
    @State private var approximateAge = ""
    @State private var estimatedAgeYears = 0
    @State private var estimatedAgeMonths = 0
    @State private var hasWeight = false
    @State private var weight = ""
    @State private var selectedDam: Cattle?
    @State private var selectedSire: Cattle?
    @State private var hasPurchaseInfo = false
    @State private var purchaseDate = Date()
    @State private var purchasePrice = ""
    @State private var purchaseWeight = ""
    @State private var purchaseType = ""
    @State private var purchasedFrom = ""
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    // Delete confirmation
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                ageSection
                parentageSection
                physicalInfoSection
                lifecycleSection
                notesSection
                deleteSection
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

    // MARK: - Form Sections

    private var basicInfoSection: some View {
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

            TextField("Color", text: $color)
            TextField("Markings", text: $markings)
        }
    }

    private var ageSection: some View {
        Section("Age") {
            Toggle("Known Date of Birth", isOn: $hasDOB)

            if hasDOB {
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Estimate age to calculate approximate DOB")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Picker("Years", selection: $estimatedAgeYears) {
                            ForEach(0...20, id: \.self) { year in
                                Text("\(year) year\(year == 1 ? "" : "s")").tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Months", selection: $estimatedAgeMonths) {
                            ForEach(0...11, id: \.self) { month in
                                Text("\(month) month\(month == 1 ? "" : "s")").tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 120)

                    if estimatedAgeYears > 0 || estimatedAgeMonths > 0 {
                        let estimatedDOB = calculateEstimatedDOB()
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Estimated DOB: \(formatDate(estimatedDOB))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    TextField("Approximate Age (optional text)", text: $approximateAge)
                        .font(.caption)
                }
            }
        }
    }

    private var parentageSection: some View {
        Section("Parentage") {
            Picker("Sire (Father)", selection: $selectedSire) {
                Text("Select...").tag(nil as Cattle?)
                ForEach(bulls, id: \.objectID) { bull in
                    Text("\(bull.tagNumber ?? "Unknown") \(bull.name != nil ? "(\(bull.name!))" : "")").tag(bull as Cattle?)
                }
            }

            Picker("Dam (Mother)", selection: $selectedDam) {
                Text("Select...").tag(nil as Cattle?)
                ForEach(cows, id: \.objectID) { cow in
                    Text("\(cow.tagNumber ?? "Unknown") \(cow.name != nil ? "(\(cow.name!))" : "")").tag(cow as Cattle?)
                }
            }
        }
    }

    private var physicalInfoSection: some View {
        Section("Physical Information") {
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
    }

    private var lifecycleSection: some View {
        Section("Lifecycle & Status") {
            Picker("Current Stage", selection: $selectedStage) {
                Text("Select Stage").tag(nil as CattleStage?)
                ForEach(cattleStages) { stage in
                    Text(stage.displayValue).tag(stage as CattleStage?)
                }
            }

            Picker("Production Path", selection: $selectedPath) {
                Text("Select Path").tag(nil as ProductionPath?)
                ForEach(productionPaths) { path in
                    Text(path.displayValue).tag(path as ProductionPath?)
                }
            }

            Picker("Type", selection: $selectedType) {
                ForEach(CattleType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            Picker("Status", selection: $selectedStatus) {
                ForEach(CattleStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }

    private var deleteSection: some View {
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

        // Find cattle stage entity by name
        if let stageName = cattle.currentStage {
            selectedStage = cattleStages.first(where: { $0.name == stageName })
        }

        // Find production path entity by name
        if let pathName = cattle.productionPath {
            selectedPath = productionPaths.first(where: { $0.name == pathName })
        }

        selectedStatus = CattleStatus(rawValue: cattle.currentStatus ?? "") ?? .active
        selectedSire = cattle.sire
        selectedDam = cattle.dam

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

        // Update parentage
        cattle.sire = selectedSire
        cattle.dam = selectedDam

        // Update lifecycle - use entity names with fallback to default values
        cattle.currentStage = selectedStage?.name ?? "Calf"
        cattle.productionPath = selectedPath?.name ?? "BeefFinishing"
        cattle.currentStatus = selectedStatus.rawValue

        // Update age
        if hasDOB {
            cattle.dateOfBirth = dateOfBirth
            cattle.approximateAge = nil
        } else if estimatedAgeYears > 0 || estimatedAgeMonths > 0 {
            cattle.dateOfBirth = calculateEstimatedDOB()
            cattle.approximateAge = approximateAge.isEmpty ? "\(estimatedAgeYears)y \(estimatedAgeMonths)m" : approximateAge
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

    // MARK: - Helper Functions

    private func calculateEstimatedDOB() -> Date {
        var components = DateComponents()
        components.year = -estimatedAgeYears
        components.month = -estimatedAgeMonths
        return Calendar.current.date(byAdding: components, to: Date()) ?? Date()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
