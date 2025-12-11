//
//  RecordDeceasedView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct RecordDeceasedView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Death Details
    @State private var deathDate = Date()
    @State private var cause = ""
    @State private var causeCategory = ""
    @State private var disposalMethod = ""
    @State private var veterinarian = ""
    @State private var necropsyPerformed = false
    @State private var necropsyResults = ""
    @State private var reportedToAuthorities = false
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // Cattle Info
                Section("Animal") {
                    HStack {
                        Text("Tag Number")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cattle.tagNumber ?? "Unknown")
                            .fontWeight(.medium)
                    }

                    if let name = cattle.name, !name.isEmpty {
                        HStack {
                            Text("Name")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(name)
                                .fontWeight(.medium)
                        }
                    }

                    if cattle.dateOfBirth != nil {
                        HStack {
                            Text("Age at Death")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(cattle.age)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Death Details
                Section("Death Information") {
                    DatePicker("Date of Death", selection: $deathDate, displayedComponents: [.date])

                    Picker("Cause Category", selection: $causeCategory) {
                        Text("Select...").tag("")
                        Text("Natural Causes").tag("Natural Causes")
                        Text("Disease").tag("Disease")
                        Text("Injury").tag("Injury")
                        Text("Calving Complications").tag("Calving Complications")
                        Text("Predator").tag("Predator")
                        Text("Accident").tag("Accident")
                        Text("Unknown").tag("Unknown")
                        Text("Other").tag("Other")
                    }

                    TextField("Specific Cause", text: $cause)
                        .autocorrectionDisabled()
                }

                // Veterinary Information
                Section("Veterinary Information") {
                    TextField("Veterinarian (Optional)", text: $veterinarian)

                    Toggle("Necropsy Performed", isOn: $necropsyPerformed)

                    if necropsyPerformed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Necropsy Results")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $necropsyResults)
                                .frame(minHeight: 80)
                        }
                    }
                }

                // Disposal and Reporting
                Section("Disposal and Reporting") {
                    Picker("Disposal Method", selection: $disposalMethod) {
                        Text("Select...").tag("")
                        Text("Burial").tag("Burial")
                        Text("Rendering").tag("Rendering")
                        Text("Composting").tag("Composting")
                        Text("Incineration").tag("Incineration")
                        Text("Other").tag("Other")
                    }

                    Toggle("Reported to Authorities", isOn: $reportedToAuthorities)

                    if reportedToAuthorities {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Record the reporting details in notes below")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Notes
                Section("Additional Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                // Warning
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status Change")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("This animal will be marked as Deceased and no longer Active.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Record Death")
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
                        recordDeath()
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

    // MARK: - Record Death

    private func recordDeath() {
        // Validation
        if cause.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter a cause of death"
            showingError = true
            return
        }

        // Create mortality record
        let mortalityRecord = MortalityRecord.create(for: cattle, in: viewContext)
        mortalityRecord.deathDate = deathDate
        mortalityRecord.cause = cause.trimmingCharacters(in: .whitespaces)

        if !causeCategory.isEmpty {
            mortalityRecord.causeCategory = causeCategory
        }

        if !disposalMethod.isEmpty {
            mortalityRecord.disposalMethod = disposalMethod
        }

        if !veterinarian.isEmpty {
            mortalityRecord.veterinarian = veterinarian.trimmingCharacters(in: .whitespaces)
        }

        mortalityRecord.necropsyPerformed = necropsyPerformed
        if necropsyPerformed && !necropsyResults.isEmpty {
            mortalityRecord.necropsyResults = necropsyResults
        }

        mortalityRecord.reportedToAuthorities = reportedToAuthorities

        if !notes.isEmpty {
            mortalityRecord.notes = notes
        }

        // Update cattle status
        cattle.currentStatus = CattleStatus.deceased.rawValue
        cattle.exitDate = deathDate
        cattle.exitReason = causeCategory.isEmpty ? "Deceased" : causeCategory
        cattle.modifiedAt = Date()

        // Save
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save mortality record: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    RecordDeceasedView(cattle: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-C001"
        cattle.name = "Sample Cow"
        cattle.currentStage = CattleStage.breeding.rawValue
        cattle.dateOfBirth = Calendar.current.date(byAdding: .year, value: -5, to: Date())
        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
