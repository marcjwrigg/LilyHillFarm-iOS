//
//  BulkHealthRecordView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BulkHealthRecordView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Health Record Fields
    @State private var date = Date()
    @State private var recordType: HealthRecordType = .treatment
    @State private var condition = ""
    @State private var treatment = ""
    @State private var medication = ""
    @State private var dosage = ""
    @State private var administrationMethod: AdministrationMethod = .injection
    @State private var veterinarian = ""
    @State private var cost = ""
    @State private var notes = ""

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

                    Picker("Type", selection: $recordType) {
                        ForEach(HealthRecordType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Condition/Diagnosis", text: $condition)
                    TextField("Treatment", text: $treatment)
                }

                // Medication Section
                Section("Medication") {
                    TextField("Medication Name", text: $medication)
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

                    TextField("Veterinarian (optional)", text: $veterinarian)
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
        }
    }

    // MARK: - Save Bulk Records

    private func saveBulkRecords() {
        // Validation
        if condition.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter a condition or diagnosis"
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
            let record = HealthRecord.create(for: cattle, type: recordType, in: viewContext)
            record.date = date
            record.condition = condition.trimmingCharacters(in: .whitespaces)

            if !treatment.isEmpty {
                record.treatment = treatment.trimmingCharacters(in: .whitespaces)
            }

            if !medication.isEmpty {
                record.medication = medication.trimmingCharacters(in: .whitespaces)
            }

            if !dosage.isEmpty {
                record.dosage = dosage.trimmingCharacters(in: .whitespaces)
            }

            record.administrationMethod = administrationMethod.rawValue

            if !veterinarian.isEmpty {
                record.veterinarian = veterinarian.trimmingCharacters(in: .whitespaces)
            }

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
