//
//  PromoteStageView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct PromoteStageView: View {
    @ObservedObject var cattle: Cattle
    let toStage: LegacyCattleStage

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var weight = ""
    @State private var notes = ""
    @State private var recordWeight = true
    @State private var showingError = false
    @State private var errorMessage = ""

    var recommendedInfo: StagePromotionInfo? {
        // Get current stage to determine which promotion info to use
        guard let currentStageEnum = LegacyCattleStage(rawValue: cattle.currentStage ?? "") else {
            return nil
        }

        switch (currentStageEnum, toStage) {
        case (.calf, .weanling):
            return .calfToWeanling
        case (.weanling, .stocker):
            return .weanlingToStocker
        case (.weanling, .breeding):
            return .weanlingToBreeding
        case (.stocker, .feeder):
            return .stockerToFeeder
        case (.stocker, .breeding):
            return .stockerToBreeding
        case (.feeder, .processed):
            return .feederToProcessed
        case (.breeding, .processed):
            return .breedingToProcessed
        default:
            return nil
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // Promotion Summary
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current Stage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(cattle.currentStage ?? "Unknown")
                                    .font(.headline)
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text("New Stage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(toStage.displayName)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }

                        Divider()

                        // Cattle info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cattle.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(cattle.tagNumber ?? "No Tag")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Recommended Info
                if let info = recommendedInfo {
                    Section("Recommendations") {
                        if let minWeight = info.recommendedMinimumWeightLbs {
                            HStack {
                                Image(systemName: "scalemass")
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading) {
                                    Text("Recommended Weight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(minWeight as NSNumber)+ lbs")
                                        .font(.subheadline)
                                }
                            }
                        }

                        if let typicalAge = info.typicalAgeMonths {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading) {
                                    Text("Typical Age")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(typicalAge) months")
                                        .font(.subheadline)
                                }
                            }
                        }

                        if let currentAge = cattle.ageInMonths {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("Current Age")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(currentAge) months old")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }

                // Weight Entry
                Section("Weight at Promotion") {
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

                        // Current weight reference
                        if let currentWeight = cattle.currentWeight as? Decimal, currentWeight > 0 {
                            Text("Previous: \(currentWeight as NSNumber) lbs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                // Additional stage-specific info
                if toStage == .weanling {
                    Section {
                        Text("This will record the weaning date and weight for this calf.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if toStage == .feeder {
                    Section {
                        Text("This will start the finishing period and begin tracking days on feed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Promote Stage")
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
                    Button("Promote") {
                        promoteStage()
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

    // MARK: - Promote

    private func promoteStage() {
        var weightValue: Decimal? = nil

        if recordWeight {
            if let parsedWeight = Decimal(string: weight) {
                weightValue = parsedWeight
            } else if !weight.isEmpty {
                errorMessage = "Invalid weight value"
                showingError = true
                return
            }
        }

        // Perform promotion
        cattle.promoteToStage(
            toStage,
            weight: weightValue,
            notes: notes.isEmpty ? nil : notes,
            context: viewContext
        )

        // Update current weight if provided
        if let weightValue = weightValue {
            cattle.currentWeight = NSDecimalNumber(decimal: weightValue)
        }

        // Save
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
    PromoteStageView(
        cattle: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            cattle.tagNumber = "LHF-001"
            cattle.name = "Test Calf"
            cattle.currentStage = LegacyCattleStage.calf.rawValue
            cattle.dateOfBirth = Calendar.current.date(byAdding: .month, value: -7, to: Date())
            return cattle
        }(),
        toStage: .weanling
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
