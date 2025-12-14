//
//  BulkHealthRecordView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData
import Supabase

// Simple struct to hold health condition data from Supabase
struct HealthConditionItemBulk: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
}

struct BulkHealthRecordView: View {
    let selectedCattle: [Cattle]
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

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TreatmentPlan.name, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default)
    private var treatmentPlans: FetchedResults<TreatmentPlan>

    // Health Record Fields
    @State private var date = Date()
    @State private var selectedRecordType: HealthRecordType?
    @State private var selectedCondition: HealthConditionItemBulk?
    @State private var treatment = ""
    @State private var selectedTreatmentPlan: TreatmentPlan?
    @State private var selectedMedications: Set<Medication> = []
    @State private var showMedicationPicker = false
    @State private var dosage = ""
    @State private var administrationMethod: AdministrationMethod = .injection
    @State private var selectedVeterinarian: Veterinarian?
    @State private var cost = ""
    @State private var notes = ""

    // Health Conditions
    @State private var healthConditions: [HealthConditionItemBulk] = []
    @State private var isLoadingConditions = false

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var totalCost: Decimal? {
        guard let costPerAnimal = Decimal(string: cost) else { return nil }
        return costPerAnimal * Decimal(selectedCattle.count)
    }

    var body: some View {
        NavigationView {
            Form {
                // Selected Cattle Summary
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedCattle.count) Animals Selected")
                                .font(.headline)
                            Text("Record will be added to all selected animals")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Show first few animals
                    ForEach(selectedCattle.prefix(3), id: \.objectID) { cattle in
                        HStack {
                            Text(cattle.displayName)
                            Spacer()
                            Text(cattle.tagNumber ?? "")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                    if selectedCattle.count > 3 {
                        Text("+ \(selectedCattle.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Health Record Details
                Section("Record Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])

                    Picker("Type", selection: $selectedRecordType) {
                        Text("Select Type").tag(nil as HealthRecordType?)
                        ForEach(healthRecordTypes) { type in
                            Text(type.displayValue).tag(type as HealthRecordType?)
                        }
                    }
                }

                // Condition Section
                Section("Condition") {
                    if isLoadingConditions {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading conditions...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Picker("Condition *", selection: $selectedCondition) {
                            Text("Select Condition").tag(nil as HealthConditionItemBulk?)
                            ForEach(healthConditions) { condition in
                                Text(condition.name).tag(condition as HealthConditionItemBulk?)
                            }
                        }
                        .onChange(of: selectedCondition) {
                            // Auto-populate notes with condition description
                            if let condition = selectedCondition, let description = condition.description, !description.isEmpty {
                                if notes.isEmpty {
                                    notes = description
                                }
                            }
                        }
                    }

                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                // Treatment Details
                Section("Treatment") {
                    TextField("Treatment", text: $treatment)
                }

                // Treatment Plan Section
                Section("Treatment Plan") {
                    Picker("Treatment Plan", selection: $selectedTreatmentPlan) {
                        Text("None").tag(nil as TreatmentPlan?)
                        ForEach(treatmentPlans) { plan in
                            Text(plan.displayValue).tag(plan as TreatmentPlan?)
                        }
                    }

                    if let plan = selectedTreatmentPlan {
                        if let condition = plan.condition {
                            HStack {
                                Text("Condition:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(condition)
                            }
                        }
                        if let description = plan.planDescription {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description:")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(description)
                                    .font(.body)
                            }
                        }
                    }
                }

                // Medication Section
                Section("Medication") {
                    MultiSelectDisplay(
                        selectedItems: selectedMedications,
                        itemLabel: { $0.displayValue },
                        placeholder: "Select medications",
                        onTap: { showMedicationPicker = true }
                    )

                    TextField("Dosage (per animal)", text: $dosage)

                    Picker("Administration Method", selection: $administrationMethod) {
                        ForEach(AdministrationMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                }

                // Cost Section
                Section("Cost") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Cost per Animal", text: $cost)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }

                    if let total = totalCost {
                        HStack {
                            Text("Total Cost")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: total).doubleValue))")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }

                    Picker("Veterinarian", selection: $selectedVeterinarian) {
                        Text("Select...").tag(nil as Veterinarian?)
                        ForEach(veterinarians) { vet in
                            Text(vet.displayValue).tag(vet as Veterinarian?)
                        }
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Bulk Health Record")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                loadHealthConditions()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save All") {
                        saveBulkRecords()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
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

    // MARK: - Save Bulk Records

    private func saveBulkRecords() {
        // Validation
        guard let condition = selectedCondition else {
            errorMessage = "Please select a condition"
            showingError = true
            return
        }

        // Validate cost if provided
        var costValue: Decimal? = nil
        if !cost.isEmpty {
            guard let parsed = Decimal(string: cost) else {
                errorMessage = "Invalid cost value"
                showingError = true
                return
            }
            costValue = parsed
        }

        // Create health records for each selected animal
        for cattle in selectedCattle {
            // Create record with default type (will be overridden below with dynamic type)
            let record = HealthRecord.create(for: cattle, type: .treatment, in: viewContext)
            record.date = date
            record.condition = condition.name

            // Save record type ID and name from dynamic lookup
            record.recordTypeId = selectedRecordType?.id
            record.recordType = selectedRecordType?.name

            // Save treatment plan relationship
            record.treatmentPlan = selectedTreatmentPlan

            if !treatment.isEmpty {
                record.treatment = treatment.trimmingCharacters(in: .whitespaces)
            }

            // Save medications as comma-separated names (for backward compatibility)
            // and as UUID array (for future use)
            if !selectedMedications.isEmpty {
                record.medication = selectedMedications.map { $0.name ?? "Unknown" }.joined(separator: ", ")
                record.medicationIds = selectedMedications.toUUIDArray() as NSArray
            }

            if !dosage.isEmpty {
                record.dosage = dosage.trimmingCharacters(in: .whitespaces)
            }

            record.administrationMethod = administrationMethod.rawValue

            // Save veterinarian ID and name
            record.veterinarianId = selectedVeterinarian?.id
            record.veterinarian = selectedVeterinarian?.name

            if let costValue = costValue {
                record.cost = NSDecimalNumber(decimal: costValue)
            }

            if !notes.isEmpty {
                record.notes = notes
            }
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

    // MARK: - Load Health Conditions

    private func loadHealthConditions() {
        isLoadingConditions = true

        _Concurrency.Task {
            do {
                // Fetch health conditions directly from Supabase
                guard SupabaseConfig.isConfigured else {
                    print("⚠️ Supabase not configured, skipping health conditions load")
                    isLoadingConditions = false
                    return
                }

                struct HealthConditionRow: Decodable {
                    let id: UUID
                    let name: String
                    let description: String?
                }

                let response: [HealthConditionRow] = try await SupabaseManager.shared.client
                    .from("health_conditions")
                    .select()
                    .order("name", ascending: true)
                    .execute()
                    .value

                healthConditions = response.map { HealthConditionItemBulk(id: $0.id, name: $0.name, description: $0.description) }
                isLoadingConditions = false
            } catch {
                print("Failed to load health conditions: \(error)")
                isLoadingConditions = false
            }
        }
    }
}

#Preview {
    BulkHealthRecordView(selectedCattle: {
        let context = PersistenceController.preview.container.viewContext
        var cattle: [Cattle] = []

        for i in 1...3 {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-\(String(format: "%03d", i))"
            animal.name = "Sample \(i)"
            cattle.append(animal)
        }

        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
