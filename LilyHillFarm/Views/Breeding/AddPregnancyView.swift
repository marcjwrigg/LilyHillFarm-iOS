//
//  AddPregnancyView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct AddPregnancyView: View {
    @ObservedObject var cattle: Cattle
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
            .navigationTitle("Add Breeding Record")
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

    // MARK: - Save Pregnancy

    private func savePregnancy() {
        // Validation
        if cattle.sex != CattleSex.cow.rawValue && cattle.sex != CattleSex.heifer.rawValue {
            validationMessage = "Only cows and heifers can be bred"
            showingValidationAlert = true
            return
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

        // Create pregnancy record
        let pregnancy = PregnancyRecord.create(for: cattle, method: breedingMethod, in: viewContext)

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
        }

        pregnancy.breedingMethod = breedingMethod.rawValue
        pregnancy.status = pregnancyStatus.rawValue

        // Natural breeding - link to herd bull
        if breedingMethod == .natural {
            pregnancy.bull = selectedSire
        }
        // AI/Embryo Transfer - store external bull info
        else {
            pregnancy.externalBullName = externalBullName.trimmingCharacters(in: .whitespaces)
            if !externalBullRegistration.isEmpty {
                pregnancy.externalBullRegistration = externalBullRegistration.trimmingCharacters(in: .whitespaces)
            }
            if !semenSource.isEmpty {
                pregnancy.semenSource = semenSource.trimmingCharacters(in: .whitespaces)
            }
            if !aiTechnician.isEmpty {
                pregnancy.aiTechnician = aiTechnician.trimmingCharacters(in: .whitespaces)
            }
        }

        if recordConfirmation {
            pregnancy.confirmedDate = confirmationDate
        }

        if !notes.isEmpty {
            pregnancy.notes = notes
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

// MARK: - Sire Picker View

struct SirePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSire: Cattle?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "currentStatus == %@ AND sex == %@",
                               CattleStatus.active.rawValue,
                               CattleSex.bull.rawValue),
        animation: .default)
    private var bulls: FetchedResults<Cattle>

    @State private var searchText = ""

    var filteredBulls: [Cattle] {
        if searchText.isEmpty {
            return Array(bulls)
        } else {
            let searchLower = searchText.lowercased()
            return bulls.filter { bull in
                let matchesTag = bull.tagNumber?.lowercased().contains(searchLower) ?? false
                let matchesName = bull.name?.lowercased().contains(searchLower) ?? false
                return matchesTag || matchesName
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search bulls", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                .cornerRadius(10)
                .padding()

                Divider()

                // Bulls list
                if filteredBulls.isEmpty {
                    EmptyStateView(
                        icon: "pawprint.circle",
                        title: "No bulls found",
                        message: searchText.isEmpty ? "Add bulls to your herd first" : "No matching bulls"
                    )
                } else {
                    List {
                        ForEach(filteredBulls, id: \.objectID) { bull in
                            Button(action: {
                                selectSire(bull)
                            }) {
                                HStack(spacing: 12) {
                                    // Photo or placeholder
                                    if let photo = bull.primaryPhoto,
                                       let thumbnailImage = photo.thumbnailImage {
                                        #if os(iOS)
                                        Image(uiImage: thumbnailImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        #elseif os(macOS)
                                        Image(nsImage: thumbnailImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        #endif
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.secondary)
                                                    .font(.caption)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bull.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text(bull.tagNumber ?? "No Tag")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if let breed = bull.breed?.name {
                                            Text(breed)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if selectedSire?.objectID == bull.objectID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Sire")
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
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(selectedSire == nil)
                }
            }
        }
    }

    // MARK: - Select Sire

    private func selectSire(_ bull: Cattle) {
        selectedSire = bull
    }
}

#Preview {
    AddPregnancyView(cattle: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-001"
        cattle.name = "Bessie"
        cattle.sex = CattleSex.cow.rawValue
        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
