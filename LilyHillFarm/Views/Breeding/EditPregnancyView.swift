//
//  EditPregnancyView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/6/25.
//

import SwiftUI
internal import CoreData

struct EditPregnancyView: View {
    @ObservedObject var pregnancy: PregnancyRecord
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var breedingDate = Date()
    @State private var useBreedingSeason = false
    @State private var breedingStartDate = Date()
    @State private var breedingEndDate = Date()
    @State private var breedingMethod: BreedingMethod = .natural
    @State private var selectedSire: Cattle?
    @State private var showingSirePicker = false
    @State private var externalBullName = ""
    @State private var externalBullRegistration = ""
    @State private var aiTechnician = ""
    @State private var semenSource = ""
    @State private var pregnancyStatus: PregnancyStatus = .bred
    @State private var confirmationDate: Date?
    @State private var recordConfirmation = false
    @State private var notes = ""
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    var estimatedDueDate: Date {
        Calendar.current.date(byAdding: .day, value: 283, to: breedingDate) ?? breedingDate
    }

    var estimatedDueDateStart: Date {
        Calendar.current.date(byAdding: .day, value: 283, to: breedingStartDate) ?? breedingStartDate
    }

    var estimatedDueDateEnd: Date {
        Calendar.current.date(byAdding: .day, value: 283, to: breedingEndDate) ?? breedingEndDate
    }

    var body: some View {
        NavigationView {
            Form {
                // Dam Section
                if let cattle = pregnancy.cow {
                    Section("Dam") {
                        HStack {
                            Text("Tag Number")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(cattle.tagNumber ?? "N/A")
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Name")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(cattle.name ?? "Not set")
                                .fontWeight(.medium)
                        }
                    }
                }

                // Breeding Details
                Section("Breeding Details") {
                    Toggle("Breeding Season (Date Range)", isOn: $useBreedingSeason)
                        .tint(.blue)

                    if useBreedingSeason {
                        DatePicker("Start Date", selection: $breedingStartDate, displayedComponents: [.date])
                        DatePicker("End Date", selection: $breedingEndDate, displayedComponents: [.date])

                        if breedingEndDate < breedingStartDate {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("End date must be after start date")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    } else {
                        DatePicker("Breeding Date", selection: $breedingDate, displayedComponents: [.date])
                    }

                    Picker("Method", selection: $breedingMethod) {
                        ForEach(BreedingMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    // Natural Breeding - Select from herd
                    if breedingMethod == .natural {
                        HStack {
                            Text("Sire")
                                .foregroundColor(.secondary)
                            Spacer()
                            if let sire = selectedSire {
                                Text(sire.displayName)
                                    .fontWeight(.medium)
                            } else {
                                Text("Select Sire")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingSirePicker = true
                        }
                    }
                    // AI or Embryo Transfer - Enter external bull info
                    else {
                        TextField("Bull Name", text: $externalBullName)
                            .autocorrectionDisabled()

                        TextField("Registration Number (Optional)", text: $externalBullRegistration)
                            .autocorrectionDisabled()

                        TextField("Semen Source (Optional)", text: $semenSource)

                        TextField("AI Technician (Optional)", text: $aiTechnician)
                    }
                }

                // Estimated Due Date
                Section {
                    if useBreedingSeason {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Estimated Calving Window")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(formatDate(estimatedDueDateStart)) - \(formatDate(estimatedDueDateEnd))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("283 days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Estimated Due Date")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(formatDate(estimatedDueDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("283 days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(useBreedingSeason ? "Estimated Calving Window" : "Estimated Due Date")
                } footer: {
                    Text("Based on average gestation period of 283 days")
                }

                // Pregnancy Status
                Section("Pregnancy Status") {
                    Picker("Status", selection: $pregnancyStatus) {
                        ForEach(PregnancyStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }

                    Toggle("Record Confirmation Date", isOn: $recordConfirmation)

                    if recordConfirmation {
                        DatePicker("Confirmation Date", selection: Binding(
                            get: { confirmationDate ?? Date() },
                            set: { confirmationDate = $0 }
                        ), displayedComponents: [.date])
                    }
                }

                // Notes
                Section("Veterinarian Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Breeding Record")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                loadExistingData()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePregnancy()
                    }
                }
            }
            .sheet(isPresented: $showingSirePicker) {
                SirePickerView(selectedSire: $selectedSire)
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Load Existing Data

    private func loadExistingData() {
        // Load breeding dates
        if let startDate = pregnancy.breedingStartDate,
           let endDate = pregnancy.breedingEndDate {
            useBreedingSeason = true
            breedingStartDate = startDate
            breedingEndDate = endDate
            breedingDate = startDate
        } else if let date = pregnancy.breedingDate {
            useBreedingSeason = false
            breedingDate = date
        }

        // Load breeding method
        if let methodString = pregnancy.breedingMethod,
           let method = BreedingMethod(rawValue: methodString) {
            breedingMethod = method
        }

        // Load sire info
        selectedSire = pregnancy.bull
        externalBullName = pregnancy.externalBullName ?? ""
        externalBullRegistration = pregnancy.externalBullRegistration ?? ""
        semenSource = pregnancy.semenSource ?? ""
        aiTechnician = pregnancy.aiTechnician ?? ""

        // Load status
        if let statusString = pregnancy.status,
           let status = PregnancyStatus(rawValue: statusString) {
            pregnancyStatus = status
        }

        // Load confirmation date
        if let confirmed = pregnancy.confirmedDate {
            recordConfirmation = true
            confirmationDate = confirmed
        }

        // Load notes
        notes = pregnancy.notes ?? ""
    }

    // MARK: - Save Pregnancy

    private func savePregnancy() {
        // Validation
        if let cattle = pregnancy.cow {
            if cattle.sex != CattleSex.cow.rawValue && cattle.sex != CattleSex.heifer.rawValue {
                validationMessage = "Only cows and heifers can be bred"
                showingValidationAlert = true
                return
            }
        }

        // Validate breeding method requirements
        if breedingMethod == .natural && selectedSire == nil {
            validationMessage = "Please select a sire for natural breeding"
            showingValidationAlert = true
            return
        }

        if (breedingMethod == .artificialInsemination || breedingMethod == .embryoTransfer) && externalBullName.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Please enter bull name for AI/Embryo Transfer"
            showingValidationAlert = true
            return
        }

        // Validate date range if using breeding season
        if useBreedingSeason && breedingEndDate < breedingStartDate {
            validationMessage = "Breeding end date must be after start date"
            showingValidationAlert = true
            return
        }

        // Update pregnancy record
        // Set breeding dates based on mode
        if useBreedingSeason {
            pregnancy.breedingStartDate = breedingStartDate
            pregnancy.breedingEndDate = breedingEndDate
            pregnancy.breedingDate = breedingStartDate // Use start date as primary
            pregnancy.expectedCalvingStartDate = estimatedDueDateStart
            pregnancy.expectedCalvingEndDate = estimatedDueDateEnd
            pregnancy.expectedCalvingDate = estimatedDueDateStart // Use start date as primary
        } else {
            pregnancy.breedingDate = breedingDate
            pregnancy.expectedCalvingDate = estimatedDueDate
            // Clear season dates if not using breeding season
            pregnancy.breedingStartDate = nil
            pregnancy.breedingEndDate = nil
            pregnancy.expectedCalvingStartDate = nil
            pregnancy.expectedCalvingEndDate = nil
        }

        pregnancy.breedingMethod = breedingMethod.rawValue
        pregnancy.status = pregnancyStatus.rawValue

        // Natural breeding - link to herd bull
        if breedingMethod == .natural {
            pregnancy.bull = selectedSire
            // Clear external bull info
            pregnancy.externalBullName = nil
            pregnancy.externalBullRegistration = nil
            pregnancy.semenSource = nil
            pregnancy.aiTechnician = nil
        }
        // AI/Embryo Transfer - store external bull info
        else {
            pregnancy.externalBullName = externalBullName.trimmingCharacters(in: .whitespaces)
            if !externalBullRegistration.isEmpty {
                pregnancy.externalBullRegistration = externalBullRegistration.trimmingCharacters(in: .whitespaces)
            } else {
                pregnancy.externalBullRegistration = nil
            }
            if !semenSource.isEmpty {
                pregnancy.semenSource = semenSource.trimmingCharacters(in: .whitespaces)
            } else {
                pregnancy.semenSource = nil
            }
            if !aiTechnician.isEmpty {
                pregnancy.aiTechnician = aiTechnician.trimmingCharacters(in: .whitespaces)
            } else {
                pregnancy.aiTechnician = nil
            }
            // Clear herd bull link
            pregnancy.bull = nil
        }

        if recordConfirmation {
            pregnancy.confirmedDate = confirmationDate
        } else {
            pregnancy.confirmedDate = nil
        }

        if !notes.isEmpty {
            pregnancy.notes = notes
        } else {
            pregnancy.notes = nil
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            validationMessage = "Failed to save pregnancy record: \(nsError.localizedDescription)"
            showingValidationAlert = true
        }
    }

    // MARK: - Helper Functions

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    EditPregnancyView(pregnancy: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-001"
        cattle.name = "Bessie"
        cattle.sex = CattleSex.cow.rawValue
        let pregnancy = PregnancyRecord.create(for: cattle, method: .natural, in: context)
        pregnancy.breedingDate = Date()
        pregnancy.status = PregnancyStatus.bred.rawValue
        return pregnancy
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
