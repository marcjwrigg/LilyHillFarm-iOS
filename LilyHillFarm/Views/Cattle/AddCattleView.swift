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

    // Basic Information
    @State private var tagNumber = ""
    @State private var name = ""
    @State private var selectedSex: CattleSex?
    @State private var selectedBreed: Breed?
    @State private var selectedType: CattleType = .beef
    @State private var color = ""
    @State private var markings = ""
    @State private var selectedStatus: CattleStatus = .active
    @State private var tags = ""

    // Lifecycle
    @State private var selectedStage: CattleStage?
    @State private var selectedPath: ProductionPath?

    // Date
    @State private var hasDOB = false
    @State private var dateOfBirth = Date()
    @State private var estimatedAgeYears = 0
    @State private var estimatedAgeMonths = 0

    // Weight
    @State private var hasWeight = false
    @State private var weight = ""

    // Parentage
    @State private var selectedDam: Cattle?
    @State private var selectedSire: Cattle?

    // Purchase Information
    @State private var hasPurchaseInfo = false
    @State private var purchaseDate = Date()
    @State private var purchasePrice = ""
    @State private var purchaseWeight = ""
    @State private var purchaseType = ""
    @State private var purchasedFrom = ""

    // Notes
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                ageSection
                parentageSection
                physicalInfoSection
                purchaseInfoSection
                lifecycleSection
                additionalInfoSection
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

    private var purchaseInfoSection: some View {
        Section("Purchase Information") {
            Toggle("Add Purchase Details", isOn: $hasPurchaseInfo)

            if hasPurchaseInfo {
                DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)

                HStack {
                    TextField("Purchase Price", text: $purchasePrice)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Text("$")
                        .foregroundColor(.secondary)
                }

                HStack {
                    TextField("Purchase Weight", text: $purchaseWeight)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Text("lbs")
                        .foregroundColor(.secondary)
                }

                Picker("Purchase Type", selection: $purchaseType) {
                    Text("Select...").tag("")
                    Text("Auction").tag("Auction")
                    Text("Private Sale").tag("Private Sale")
                    Text("Bred and Born").tag("Bred and Born")
                    Text("Gift").tag("Gift")
                    Text("Other").tag("Other")
                }

                TextField("Purchased From", text: $purchasedFrom)
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

    private var additionalInfoSection: some View {
        Section {
            TextField("Tags (comma-separated)", text: $tags)
                .autocapitalization(.none)

            TextEditor(text: $notes)
                .frame(minHeight: 100)
        } header: {
            Text("Additional Information")
        } footer: {
            Text("Tags help categorize and filter cattle (e.g., Organic, Grass-fed, Replacement)")
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !tagNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedSex != nil
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
        cattle.currentStatus = selectedStatus.rawValue
        cattle.tags = tags.isEmpty ? nil : tags

        // Age
        if hasDOB {
            cattle.dateOfBirth = dateOfBirth
        } else if estimatedAgeYears > 0 || estimatedAgeMonths > 0 {
            cattle.dateOfBirth = calculateEstimatedDOB()
            cattle.approximateAge = "\(estimatedAgeYears)y \(estimatedAgeMonths)m"
        }

        // Parentage
        cattle.dam = selectedDam
        cattle.sire = selectedSire

        // Lifecycle
        cattle.currentStage = selectedStage?.name ?? "Calf"
        cattle.productionPath = selectedPath?.name ?? "BeefFinishing"

        // Weight
        if hasWeight, let weightValue = Decimal(string: weight) {
            cattle.currentWeight = NSDecimalNumber(decimal: weightValue)
        }

        // Purchase information
        if hasPurchaseInfo {
            cattle.purchaseDate = purchaseDate

            if let priceValue = Decimal(string: purchasePrice) {
                cattle.purchasePrice = NSDecimalNumber(decimal: priceValue)
            }

            if let weightValue = Decimal(string: purchaseWeight) {
                cattle.purchaseWeight = NSDecimalNumber(decimal: weightValue)
            }

            cattle.purchaseType = purchaseType.isEmpty ? nil : purchaseType
            cattle.purchasedFrom = purchasedFrom.isEmpty ? nil : purchasedFrom
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
    AddCattleView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
