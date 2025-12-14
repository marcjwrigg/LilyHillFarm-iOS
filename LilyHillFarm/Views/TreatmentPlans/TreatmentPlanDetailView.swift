//
//  TreatmentPlanDetailView.swift
//  LilyHillFarm
//
//  Detailed view of a treatment plan showing all steps
//

import SwiftUI
internal import CoreData

struct TreatmentPlanDetailView: View {
    @ObservedObject var treatmentPlan: TreatmentPlan

    var sortedSteps: [TreatmentPlanStep] {
        guard let steps = treatmentPlan.steps as? Set<TreatmentPlanStep> else {
            return []
        }
        return steps.sorted { $0.stepNumber < $1.stepNumber }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Info
                VStack(alignment: .leading, spacing: 12) {
                    // Condition Badge
                    if let condition = treatmentPlan.condition {
                        HStack {
                            Image(systemName: "cross.case")
                                .font(.caption)
                            Text(condition)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }

                    // Description
                    if let description = treatmentPlan.planDescription, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    // Notes
                    if let notes = treatmentPlan.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "note.text")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Notes")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            Text(notes)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                // Treatment Steps
                if sortedSteps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Steps Defined")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Add steps to this treatment plan in the web app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        // Header
                        HStack {
                            Text("Treatment Steps")
                                .font(.headline)
                            Spacer()
                            Text("\(sortedSteps.count) step\(sortedSteps.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        Divider()
                            .padding(.horizontal)

                        // Steps List
                        ForEach(sortedSteps, id: \.objectID) { step in
                            TreatmentPlanStepRow(step: step)

                            if step.objectID != sortedSteps.last?.objectID {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }

                // Disclaimer at Bottom
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Text("Use the web app to add or modify treatment plans and steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(treatmentPlan.name ?? "Treatment Plan")
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        #endif
    }
}

// MARK: - Treatment Plan Step Row

struct TreatmentPlanStepRow: View {
    let step: TreatmentPlanStep

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step Number Badge
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                Text("\(step.stepNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Step Title
                HStack(alignment: .top) {
                    Text(step.title ?? "Step \(step.stepNumber)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    // Day Badge
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("Day \(step.dayNumber)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                }

                // Description
                if let description = step.stepDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Medication Info
                if let medication = step.medication, !medication.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "pills")
                                .font(.caption2)
                                .foregroundColor(.purple)
                            Text("Medication:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                            Text(medication)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let dosage = step.dosage, !dosage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "syringe")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                Text("Dosage:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                                Text(dosage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let method = step.administrationMethod, !method.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.right")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                Text("Method:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                                Text(method)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(8)
                }

                // Notes
                if let notes = step.notes, !notes.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        // Preview with mock data would go here
        Text("Treatment Plan Detail Preview")
    }
}
