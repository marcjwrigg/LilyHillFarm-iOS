//
//  BulkPromoteStageView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BulkPromoteStageView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Promotion Fields
    @State private var recordWeight = false
    @State private var weight = ""
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    // Bulk Processing
    @State private var showingBulkProcessing = false

    // Cattle going to processed (need special handling)
    var cattleGoingToProcessed: [Cattle] {
        selectedCattle.filter { $0.nextStage() == .processed }
    }

    // Group cattle by their next stage (excluding processed)
    var cattleByNextStage: [(stage: CattleStage, cattle: [Cattle])] {
        var grouped: [CattleStage: [Cattle]] = [:]

        for cattle in selectedCattle {
            if let nextStage = cattle.nextStage(), nextStage != .processed {
                grouped[nextStage, default: []].append(cattle)
            }
        }

        return grouped.map { (stage: $0.key, cattle: $0.value) }.sorted { $0.stage.rawValue < $1.stage.rawValue }
    }

    var cattleWithoutNextStage: [Cattle] {
        selectedCattle.filter { $0.nextStage() == nil }
    }

    var body: some View {
        NavigationView {
            Form {
                // Selected Cattle Summary
                Section {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedCattle.count) Animals Selected")
                                .font(.headline)
                            Text("Promote to next stage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Grouped by next stage
                ForEach(cattleByNextStage, id: \.stage) { group in
                    Section("→ \(group.stage.displayName)") {
                        ForEach(group.cattle, id: \.objectID) { cattle in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cattle.displayName)
                                        .font(.subheadline)
                                    Text("\(cattle.currentStage ?? "Unknown") → \(group.stage.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(cattle.tagNumber ?? "")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Cattle going to processed (requires bulk processing)
                if !cattleGoingToProcessed.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(cattleGoingToProcessed.count) Ready for Processing")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("These animals require individual processing details")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        ForEach(cattleGoingToProcessed, id: \.objectID) { cattle in
                            HStack {
                                Text(cattle.displayName)
                                Spacer()
                                Text(cattle.tagNumber ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button(action: {
                            showingBulkProcessing = true
                        }) {
                            HStack {
                                Image(systemName: "scalemass.fill")
                                Text("Record Processing Details")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Cannot be promoted
                if !cattleWithoutNextStage.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(cattleWithoutNextStage.count) Cannot Be Promoted")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("These animals are at a terminal stage or missing requirements")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        ForEach(cattleWithoutNextStage, id: \.objectID) { cattle in
                            HStack {
                                Text(cattle.displayName)
                                Spacer()
                                Text(cattle.currentStage ?? "Unknown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Weight Entry (Optional)
                Section("Weight at Promotion (Optional)") {
                    Toggle("Record Weight", isOn: $recordWeight)

                    if recordWeight {
                        HStack {
                            TextField("Weight (applies to all)", text: $weight)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("lbs")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Notes
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Bulk Promote Stage")
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
                    Button("Promote All") {
                        promoteAll()
                    }
                    .disabled(cattleByNextStage.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingBulkProcessing) {
                BulkProcessingView(selectedCattle: cattleGoingToProcessed)
            }
        }
    }

    // MARK: - Promote All

    private func promoteAll() {
        // Validation
        var weightValue: Decimal? = nil
        if recordWeight {
            if !weight.isEmpty {
                guard let parsed = Decimal(string: weight) else {
                    errorMessage = "Invalid weight value"
                    showingError = true
                    return
                }
                weightValue = parsed
            }
        }

        // Promote each cattle to their next stage
        for group in cattleByNextStage {
            for cattle in group.cattle {
                cattle.promoteToStage(
                    group.stage,
                    weight: weightValue,
                    notes: notes.isEmpty ? nil : notes,
                    context: viewContext
                )

                // Update current weight if provided
                if let weightValue = weightValue {
                    cattle.currentWeight = NSDecimalNumber(decimal: weightValue)
                }

                // Special handling for processed stage
                if group.stage == .processed {
                    cattle.currentStatus = CattleStatus.processed.rawValue
                    cattle.exitDate = Date()
                    cattle.exitReason = "Processed"
                }
            }
        }

        // Save all changes
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to promote: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    BulkPromoteStageView(selectedCattle: {
        let context = PersistenceController.preview.container.viewContext
        var cattle: [Cattle] = []

        for i in 1...3 {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-\(String(format: "%03d", i))"
            animal.name = "Sample \(i)"
            animal.currentStage = CattleStage.calf.rawValue
            animal.dateOfBirth = Calendar.current.date(byAdding: .month, value: -7, to: Date())
            cattle.append(animal)
        }

        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
