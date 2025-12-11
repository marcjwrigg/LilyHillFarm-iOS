//
//  RecordProcessingView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct RecordProcessingView: View {
    @ObservedObject var cattle: Cattle
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

                // Warning
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status Change")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("This animal will be marked as Processed and no longer Active.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Record Processing")
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
                        recordProcessing()
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

    // MARK: - Record Processing

    private func recordProcessing() {
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

        // Create processing record
        let processingRecord = ProcessingRecord.create(for: cattle, in: viewContext)
        processingRecord.processingDate = processingDate
        processingRecord.processor = processor.isEmpty ? nil : processor

        if let liveWeightValue = liveWeightValue {
            processingRecord.liveWeight = NSDecimalNumber(decimal: liveWeightValue)
        }

        if let hangingWeightValue = hangingWeightValue {
            processingRecord.hangingWeight = NSDecimalNumber(decimal: hangingWeightValue)
        }

        if let costValue = costValue {
            processingRecord.processingCost = NSDecimalNumber(decimal: costValue)
        }

        // Calculate and store dress percentage
        if let dressPercent = dressPercentage {
            processingRecord.dressPercentage = NSDecimalNumber(decimal: dressPercent)
        }

        processingRecord.notes = notes.isEmpty ? nil : notes

        // Update cattle status
        cattle.currentStage = CattleStage.processed.rawValue
        cattle.currentStatus = CattleStatus.processed.rawValue
        cattle.processingDate = processingDate
        cattle.exitDate = processingDate
        cattle.exitReason = "Processed"
        cattle.modifiedAt = Date()

        // Save
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save processing record: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    RecordProcessingView(cattle: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-F001"
        cattle.name = "Sample Feeder"
        cattle.currentStage = CattleStage.feeder.rawValue
        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
