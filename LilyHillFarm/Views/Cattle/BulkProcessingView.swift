//
//  BulkProcessingView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BulkProcessingView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Common Processing Details
    @State private var processingDate = Date()
    @State private var processor = ""
    @State private var notes = ""

    // Individual details for each animal
    @State private var individualLiveWeights: [NSManagedObjectID: String] = [:]
    @State private var individualHangingWeights: [NSManagedObjectID: String] = [:]
    @State private var individualCosts: [NSManagedObjectID: String] = [:]

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var totalProcessingCost: Decimal {
        var total: Decimal = 0
        for (_, costString) in individualCosts {
            if let cost = Decimal(string: costString) {
                total += cost
            }
        }
        return total
    }

    var averageDressPercentage: Decimal? {
        var sum: Decimal = 0
        var count = 0

        for cattle in selectedCattle {
            if let liveWeight = Decimal(string: individualLiveWeights[cattle.objectID] ?? ""),
               let hangingWeight = Decimal(string: individualHangingWeights[cattle.objectID] ?? ""),
               liveWeight > 0 {
                let dressPercent = (hangingWeight / liveWeight) * 100
                sum += dressPercent
                count += 1
            }
        }

        return count > 0 ? sum / Decimal(count) : nil
    }

    func dressPercentage(for cattle: Cattle) -> Decimal? {
        guard let liveWeight = Decimal(string: individualLiveWeights[cattle.objectID] ?? ""),
              let hangingWeight = Decimal(string: individualHangingWeights[cattle.objectID] ?? ""),
              liveWeight > 0 else {
            return nil
        }
        return (hangingWeight / liveWeight) * 100
    }

    var body: some View {
        NavigationView {
            Form {
                // Selected Cattle Summary
                Section {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedCattle.count) Animals Selected")
                                .font(.headline)
                            Text("Enter processing details for each animal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if totalProcessingCost > 0 {
                        HStack {
                            Text("Total Processing Cost")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: totalProcessingCost).doubleValue))")
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                                .font(.title3)
                        }
                    }

                    if let avgDress = averageDressPercentage {
                        HStack {
                            Text("Average Dress %")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", NSDecimalNumber(decimal: avgDress).doubleValue))
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Individual Processing Details
                Section("Processing Details") {
                    ForEach(selectedCattle, id: \.objectID) { cattle in
                        VStack(alignment: .leading, spacing: 12) {
                            // Animal Header
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cattle.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(cattle.tagNumber ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }

                            // Live Weight
                            HStack {
                                Text("Live Weight")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 90, alignment: .leading)
                                TextField("Weight", text: Binding(
                                    get: { individualLiveWeights[cattle.objectID] ?? "" },
                                    set: { individualLiveWeights[cattle.objectID] = $0 }
                                ))
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                Text("lbs")
                                    .foregroundColor(.secondary)
                            }

                            // Hanging Weight
                            HStack {
                                Text("Hanging Weight")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 90, alignment: .leading)
                                TextField("Weight", text: Binding(
                                    get: { individualHangingWeights[cattle.objectID] ?? "" },
                                    set: { individualHangingWeights[cattle.objectID] = $0 }
                                ))
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                Text("lbs")
                                    .foregroundColor(.secondary)
                            }

                            // Show calculated dress percentage
                            if let dressPercent = dressPercentage(for: cattle) {
                                HStack {
                                    Text("Dress %")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 90, alignment: .leading)
                                    Text(String(format: "%.1f%%", NSDecimalNumber(decimal: dressPercent).doubleValue))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                            }

                            // Processing Cost
                            HStack {
                                Text("Cost")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 90, alignment: .leading)
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("Processing Cost", text: Binding(
                                    get: { individualCosts[cattle.objectID] ?? "" },
                                    set: { individualCosts[cattle.objectID] = $0 }
                                ))
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            }

                            Divider()
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Common Processing Information
                Section("Processor Information") {
                    DatePicker("Processing Date", selection: $processingDate, displayedComponents: [.date])

                    TextField("Processor/Facility", text: $processor)
                }

                // Notes
                Section("Notes (Applied to all)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
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
                            Text("All selected animals will be marked as Processed and no longer Active.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Bulk Processing")
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
                    Button("Record All") {
                        recordBulkProcessing()
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

    // MARK: - Record Bulk Processing

    private func recordBulkProcessing() {
        // Validation
        if processor.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter processor/facility name"
            showingError = true
            return
        }

        // Validate that all animals have required fields entered
        for cattle in selectedCattle {
            // Validate live weight
            if let liveWeightString = individualLiveWeights[cattle.objectID] {
                guard !liveWeightString.isEmpty, Decimal(string: liveWeightString) != nil else {
                    errorMessage = "Please enter a valid live weight for \(cattle.displayName)"
                    showingError = true
                    return
                }
            } else {
                errorMessage = "Please enter live weight for \(cattle.displayName)"
                showingError = true
                return
            }

            // Validate hanging weight
            if let hangingWeightString = individualHangingWeights[cattle.objectID] {
                guard !hangingWeightString.isEmpty, Decimal(string: hangingWeightString) != nil else {
                    errorMessage = "Please enter a valid hanging weight for \(cattle.displayName)"
                    showingError = true
                    return
                }
            } else {
                errorMessage = "Please enter hanging weight for \(cattle.displayName)"
                showingError = true
                return
            }

            // Validate cost (optional but if entered must be valid)
            if let costString = individualCosts[cattle.objectID], !costString.isEmpty {
                guard Decimal(string: costString) != nil else {
                    errorMessage = "Please enter a valid processing cost for \(cattle.displayName)"
                    showingError = true
                    return
                }
            }
        }

        // Create processing records for each animal
        for cattle in selectedCattle {
            guard let liveWeightString = individualLiveWeights[cattle.objectID],
                  let liveWeight = Decimal(string: liveWeightString),
                  let hangingWeightString = individualHangingWeights[cattle.objectID],
                  let hangingWeight = Decimal(string: hangingWeightString) else {
                continue
            }

            // Create processing record
            let processingRecord = ProcessingRecord.create(for: cattle, in: viewContext)
            processingRecord.processingDate = processingDate
            processingRecord.processor = processor.trimmingCharacters(in: .whitespaces)
            processingRecord.liveWeight = NSDecimalNumber(decimal: liveWeight)
            processingRecord.hangingWeight = NSDecimalNumber(decimal: hangingWeight)

            // Calculate dress percentage
            let dressPercent = (hangingWeight / liveWeight) * 100
            processingRecord.dressPercentage = NSDecimalNumber(decimal: dressPercent)

            // Add cost if provided
            if let costString = individualCosts[cattle.objectID],
               let cost = Decimal(string: costString), cost > 0 {
                processingRecord.processingCost = NSDecimalNumber(decimal: cost)
            }

            if !notes.isEmpty {
                processingRecord.notes = notes
            }

            // Update cattle
            cattle.currentStage = LegacyCattleStage.processed.rawValue
            cattle.currentStatus = CattleStatus.processed.rawValue
            cattle.processingDate = processingDate
            cattle.exitDate = processingDate
            cattle.exitReason = "Processed"
            cattle.currentWeight = NSDecimalNumber(decimal: liveWeight)
            cattle.modifiedAt = Date()
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
    BulkProcessingView(selectedCattle: {
        let context = PersistenceController.preview.container.viewContext
        var cattle: [Cattle] = []

        for i in 1...3 {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-F\(String(format: "%03d", i))"
            animal.name = "Feeder \(i)"
            animal.currentStage = LegacyCattleStage.feeder.rawValue
            animal.currentWeight = NSDecimalNumber(decimal: Decimal(1100 + (i * 50)))
            cattle.append(animal)
        }

        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
