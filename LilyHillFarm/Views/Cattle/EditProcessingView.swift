//
//  EditProcessingView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct EditProcessingView: View {
    @ObservedObject var processingRecord: ProcessingRecord
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Processing Details
    @State private var processingDate = Date()
    @State private var processor = ""
    @State private var liveWeight = ""
    @State private var hangingWeight = ""
    @State private var processingCost = ""
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var dressPercentage: Decimal? {
        guard let live = Decimal(string: liveWeight),
              let hanging = Decimal(string: hangingWeight),
              live > 0 else {
            return nil
        }
        return (hanging / live) * 100
    }

    var body: some View {
        NavigationView {
            Form {
                // Cattle Info
                Section("Animal") {
                    if let cattle = processingRecord.cattle {
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
                    }
                }

                // Processing Details
                Section("Processing Information") {
                    DatePicker("Processing Date", selection: $processingDate, displayedComponents: [.date])

                    TextField("Processor/Facility", text: $processor)
                }

                // Weights
                Section("Weights") {
                    HStack {
                        TextField("Live Weight", text: $liveWeight)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("lbs")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        TextField("Hanging Weight", text: $hangingWeight)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("lbs")
                            .foregroundColor(.secondary)
                    }

                    // Display calculated dress percentage
                    if let dressPercent = dressPercentage {
                        HStack {
                            Text("Dress Percentage")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", NSDecimalNumber(decimal: dressPercent).doubleValue))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Cost
                Section("Cost") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Processing Cost", text: $processingCost)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Processing Details")
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
                        saveChanges()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadData()
            }
        }
    }

    // MARK: - Load Data

    private func loadData() {
        processingDate = processingRecord.processingDate ?? Date()
        processor = processingRecord.processor ?? ""

        if let live = processingRecord.liveWeight as? Decimal, live > 0 {
            liveWeight = "\(live)"
        }

        if let hanging = processingRecord.hangingWeight as? Decimal, hanging > 0 {
            hangingWeight = "\(hanging)"
        }

        if let cost = processingRecord.processingCost as? Decimal, cost > 0 {
            processingCost = "\(cost)"
        }

        notes = processingRecord.notes ?? ""
    }

    // MARK: - Save Changes

    private func saveChanges() {
        // Validation
        var liveWeightValue: Decimal? = nil
        var hangingWeightValue: Decimal? = nil
        var costValue: Decimal? = nil

        if !liveWeight.isEmpty {
            guard let parsed = Decimal(string: liveWeight) else {
                errorMessage = "Invalid live weight"
                showingError = true
                return
            }
            liveWeightValue = parsed
        }

        if !hangingWeight.isEmpty {
            guard let parsed = Decimal(string: hangingWeight) else {
                errorMessage = "Invalid hanging weight"
                showingError = true
                return
            }
            hangingWeightValue = parsed
        }

        if !processingCost.isEmpty {
            guard let parsed = Decimal(string: processingCost) else {
                errorMessage = "Invalid processing cost"
                showingError = true
                return
            }
            costValue = parsed
        }

        // Update processing record
        processingRecord.processingDate = processingDate
        processingRecord.processor = processor.isEmpty ? nil : processor

        if let liveWeightValue = liveWeightValue {
            processingRecord.liveWeight = NSDecimalNumber(decimal: liveWeightValue)
        } else {
            processingRecord.liveWeight = nil
        }

        if let hangingWeightValue = hangingWeightValue {
            processingRecord.hangingWeight = NSDecimalNumber(decimal: hangingWeightValue)
        } else {
            processingRecord.hangingWeight = nil
        }

        if let costValue = costValue {
            processingRecord.processingCost = NSDecimalNumber(decimal: costValue)
        } else {
            processingRecord.processingCost = nil
        }

        // Calculate and store dress percentage
        if let dressPercent = dressPercentage {
            processingRecord.dressPercentage = NSDecimalNumber(decimal: dressPercent)
        } else {
            processingRecord.dressPercentage = nil
        }

        processingRecord.notes = notes.isEmpty ? nil : notes

        // Update cattle processing date if changed
        if let cattle = processingRecord.cattle {
            cattle.processingDate = processingDate
            cattle.modifiedAt = Date()
        }

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
    EditProcessingView(processingRecord: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-F001"
        cattle.name = "Sample Feeder"

        let record = ProcessingRecord.create(for: cattle, in: context)
        record.processingDate = Date()
        record.processor = "ABC Processing"
        record.liveWeight = NSDecimalNumber(decimal: Decimal(1200))
        record.hangingWeight = NSDecimalNumber(decimal: Decimal(720))
        record.processingCost = NSDecimalNumber(decimal: Decimal(450))

        return record
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
