//
//  EditHealthRecordView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/6/25.
//

import SwiftUI
internal import CoreData

struct EditHealthRecordView: View {
    @ObservedObject var healthRecord: HealthRecord
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HealthRecordType.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var healthRecordTypes: FetchedResults<HealthRecordType>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Medication.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var medications: FetchedResults<Medication>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Veterinarian.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var veterinarians: FetchedResults<Veterinarian>

    // Record details
    @State private var selectedRecordType: HealthRecordType?
    @State private var date = Date()
    @State private var condition = ""
    @State private var treatment = ""
    @State private var selectedMedications: Set<Medication> = []
    @State private var showMedicationPicker = false
    @State private var dosage = ""
    @State private var administrationMethod: AdministrationMethod?
    @State private var selectedVeterinarian: Veterinarian?
    @State private var notes = ""

    // Measurements
    @State private var recordTemperature = false
    @State private var temperature = ""
    @State private var recordWeight = false
    @State private var weight = ""
    @State private var recordCost = false
    @State private var cost = ""

    // Follow-up
    @State private var needsFollowUp = false
    @State private var followUpDate = Date()
    @State private var followUpCompleted = false

    // Treatment Plan
    @State private var treatmentPlans: [TreatmentPlan] = []
    @State private var selectedTreatmentPlan: TreatmentPlan?
    @State private var isLoadingPlans = false

    // Photos
    @State private var showingPhotoPicker = false
    @State private var showingPhotoSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    #if os(iOS)
    @State private var selectedImages: [UIImage] = []
    #else
    @State private var selectedImages: [NSImage] = []
    #endif

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section("Record Information") {
                    Picker("Type *", selection: $selectedRecordType) {
                        Text("Select Type").tag(nil as HealthRecordType?)
                        ForEach(healthRecordTypes) { type in
                            Text(type.displayValue).tag(type as HealthRecordType?)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                // Condition/Diagnosis
                Section("Condition") {
                    TextField("Condition or Diagnosis", text: $condition)
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                // Treatment Plan
                Section("Treatment Plan") {
                    if isLoadingPlans {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading treatment plans...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Picker("Treatment Plan", selection: $selectedTreatmentPlan) {
                            Text("None").tag(nil as TreatmentPlan?)
                            ForEach(treatmentPlans, id: \.id) { plan in
                                Text(plan.name ?? "Unknown").tag(plan as TreatmentPlan?)
                            }
                        }

                        if let selected = selectedTreatmentPlan {
                            VStack(alignment: .leading, spacing: 4) {
                                if let description = selected.planDescription, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let condition = selected.condition, !condition.isEmpty {
                                    HStack {
                                        Text("Condition:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(condition)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // Treatment
                Section("Treatment") {
                    TextField("Treatment", text: $treatment)

                    MultiSelectDisplay(
                        selectedItems: selectedMedications,
                        itemLabel: { $0.displayValue },
                        placeholder: "Select medications",
                        onTap: { showMedicationPicker = true }
                    )

                    TextField("Dosage", text: $dosage)

                    Picker("Administration Method", selection: $administrationMethod) {
                        Text("Select...").tag(nil as AdministrationMethod?)
                        ForEach(AdministrationMethod.allCases) { method in
                            Text(method.rawValue).tag(method as AdministrationMethod?)
                        }
                    }

                    Picker("Veterinarian", selection: $selectedVeterinarian) {
                        Text("Select...").tag(nil as Veterinarian?)
                        ForEach(veterinarians) { vet in
                            Text(vet.displayValue).tag(vet as Veterinarian?)
                        }
                    }
                }

                // Measurements
                Section("Measurements") {
                    Toggle("Record Temperature", isOn: $recordTemperature)
                    if recordTemperature {
                        HStack {
                            TextField("Temperature", text: $temperature)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("°F")
                                .foregroundColor(.secondary)
                        }

                        if let temp = Decimal(string: temperature), !CattleValidation.isValidTemperature(temp) {
                            Text("Normal range: 100-103°F")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    Toggle("Record Weight", isOn: $recordWeight)
                    if recordWeight {
                        HStack {
                            TextField("Weight", text: $weight)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("lbs")
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("Record Cost", isOn: $recordCost)
                    if recordCost {
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("Cost", text: $cost)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    }
                }

                // Follow-up
                Section("Follow-up") {
                    Toggle("Needs Follow-up", isOn: $needsFollowUp)

                    if needsFollowUp {
                        DatePicker("Follow-up Date", selection: $followUpDate, displayedComponents: .date)
                        Toggle("Follow-up Completed", isOn: $followUpCompleted)
                    }
                }

                // Photos
                Section("Photos") {
                    Button(action: {
                        showingPhotoSourcePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.blue)
                            Text("Add Photos")
                            Spacer()
                            if !selectedImages.isEmpty {
                                Text("\(selectedImages.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<selectedImages.count, id: \.self) { index in
                                    #if os(iOS)
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            Button(action: {
                                                selectedImages.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4),
                                            alignment: .topTrailing
                                        )
                                    #else
                                    Image(nsImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            Button(action: {
                                                selectedImages.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4),
                                            alignment: .topTrailing
                                        )
                                    #endif
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Cattle info
                if let cattle = healthRecord.cattle {
                    Section {
                        HStack {
                            Text("Cattle")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(cattle.displayName)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Tag Number")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(cattle.tagNumber ?? "N/A")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("Edit Health Record")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .onAppear {
                loadExistingData()
                loadTreatmentPlans()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecord()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Add Photo", isPresented: $showingPhotoSourcePicker) {
                #if os(iOS)
                Button("Take Photo") {
                    showingCamera = true
                }
                Button("Choose from Library") {
                    showingPhotoLibrary = true
                }
                Button("Cancel", role: .cancel) {}
                #endif
            }
            .sheet(isPresented: $showingCamera) {
                #if os(iOS)
                ImagePickerController(sourceType: .camera) { image in
                    selectedImages.append(image)
                }
                #endif
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                #if os(iOS)
                PhotosLibraryPicker(maxSelection: 10 - selectedImages.count) { images in
                    selectedImages.append(contentsOf: images)
                }
                #endif
            }
            .sheet(isPresented: $showingPhotoPicker) {
                #if os(iOS)
                PhotoPickerView(maxSelection: 10) { images in
                    selectedImages.append(contentsOf: images)
                }
                #else
                PhotoPickerView(maxSelection: 10) { images in
                    selectedImages.append(contentsOf: images)
                }
                #endif
            }
            .sheet(isPresented: $showMedicationPicker) {
                MultiSelectPicker(
                    title: "Select Medications",
                    items: Array(medications),
                    selectedItems: $selectedMedications,
                    itemLabel: { $0.displayValue }
                )
            }
        }
    }

    // MARK: - Load Existing Data

    private func loadExistingData() {
        // Load record type entity by name
        if let typeName = healthRecord.recordType {
            selectedRecordType = healthRecordTypes.first(where: { $0.name == typeName })
        }

        date = healthRecord.date ?? Date()
        condition = healthRecord.condition ?? ""
        treatment = healthRecord.treatment ?? ""

        // Load medications from medicationIds array
        if let medicationIdsArray = healthRecord.medicationIds as? [UUID] {
            selectedMedications = Set(medications.filter { medication in
                medicationIdsArray.contains(medication.id ?? UUID())
            })
        }

        dosage = healthRecord.dosage ?? ""

        // Load veterinarian entity by ID
        if let vetId = healthRecord.veterinarianId {
            selectedVeterinarian = veterinarians.first(where: { $0.id == vetId })
        }

        notes = healthRecord.notes ?? ""

        if let method = healthRecord.administrationMethod {
            administrationMethod = AdministrationMethod(rawValue: method)
        }

        // Measurements
        if let temp = healthRecord.temperature as? Decimal {
            recordTemperature = true
            temperature = "\(temp)"
        }

        if let weightValue = healthRecord.weight as? Decimal {
            recordWeight = true
            weight = "\(weightValue)"
        }

        if let costValue = healthRecord.cost as? Decimal {
            recordCost = true
            cost = "\(costValue)"
        }

        // Follow-up
        if let followUp = healthRecord.followUpDate {
            needsFollowUp = true
            followUpDate = followUp
            followUpCompleted = healthRecord.followUpCompleted
        }

        // Treatment Plan - will be loaded after plans are fetched
    }

    // MARK: - Save

    private func saveRecord() {
        healthRecord.date = date

        // Save record type ID and name from dynamic lookup
        healthRecord.recordTypeId = selectedRecordType?.id
        healthRecord.recordType = selectedRecordType?.name ?? "Checkup"

        healthRecord.condition = condition.isEmpty ? nil : condition
        healthRecord.treatment = treatment.isEmpty ? nil : treatment

        // Save medications as comma-separated names (for backward compatibility)
        // and as UUID array (for future use)
        if !selectedMedications.isEmpty {
            healthRecord.medication = selectedMedications.map { $0.name ?? "Unknown" }.joined(separator: ", ")
            healthRecord.medicationIds = selectedMedications.toUUIDArray() as NSArray
        } else {
            healthRecord.medication = nil
            healthRecord.medicationIds = nil
        }

        healthRecord.dosage = dosage.isEmpty ? nil : dosage
        healthRecord.administrationMethod = administrationMethod?.rawValue

        // Save veterinarian ID and name
        healthRecord.veterinarianId = selectedVeterinarian?.id
        healthRecord.veterinarian = selectedVeterinarian?.name
        healthRecord.notes = notes.isEmpty ? nil : notes

        // Measurements
        if recordTemperature, let temp = Decimal(string: temperature) {
            healthRecord.temperature = NSDecimalNumber(decimal: temp)
        } else {
            healthRecord.temperature = nil
        }

        if recordWeight, let weightValue = Decimal(string: weight) {
            healthRecord.weight = NSDecimalNumber(decimal: weightValue)
            // Update cattle current weight
            healthRecord.cattle?.currentWeight = NSDecimalNumber(decimal: weightValue)
        } else {
            healthRecord.weight = nil
        }

        if recordCost, let costValue = Decimal(string: cost) {
            healthRecord.cost = NSDecimalNumber(decimal: costValue)
        } else {
            healthRecord.cost = nil
        }

        // Follow-up
        if needsFollowUp {
            healthRecord.followUpDate = followUpDate
            healthRecord.followUpCompleted = followUpCompleted
        } else {
            healthRecord.followUpDate = nil
            healthRecord.followUpCompleted = false
        }

        // Treatment Plan
        if let treatmentPlan = selectedTreatmentPlan {
            healthRecord.treatmentPlanId = treatmentPlan.id
        } else {
            healthRecord.treatmentPlanId = nil
        }

        // Add photos
        for (index, image) in selectedImages.enumerated() {
            let photo = Photo.create(for: healthRecord, in: viewContext)
            photo.setThumbnail(from: image)
            photo.isPrimary = (index == 0) // First photo is primary
            photo.caption = nil
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save record: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Load Treatment Plans

    private func loadTreatmentPlans() {
        isLoadingPlans = true

        _Concurrency.Task {
            do {
                // Fetch treatment plans from Supabase
                let repository = TreatmentPlanRepository(context: viewContext)
                try await repository.syncFromSupabase()

                // Fetch from Core Data
                let fetchRequest: NSFetchRequest<TreatmentPlan> = TreatmentPlan.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TreatmentPlan.name, ascending: true)]

                treatmentPlans = try viewContext.fetch(fetchRequest)

                // Set selected treatment plan if exists
                if let planId = healthRecord.treatmentPlanId {
                    selectedTreatmentPlan = treatmentPlans.first { $0.id == planId }
                }

                isLoadingPlans = false
            } catch {
                print("Failed to load treatment plans: \(error)")
                isLoadingPlans = false
            }
        }
    }
}

#Preview {
    EditHealthRecordView(healthRecord: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-001"
        cattle.name = "Test Cow"
        let record = HealthRecord.create(for: cattle, type: .checkup, in: context)
        record.condition = "Test Condition"
        return record
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
