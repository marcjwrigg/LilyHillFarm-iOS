//
//  TreatmentPlansListView.swift
//  LilyHillFarm
//
//  Read-only view of treatment plans and protocols
//

import SwiftUI
internal import CoreData

struct TreatmentPlansListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TreatmentPlan.condition, ascending: true),
            NSSortDescriptor(keyPath: \TreatmentPlan.name, ascending: true)
        ],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default)
    private var treatmentPlans: FetchedResults<TreatmentPlan>

    // Group treatment plans by condition
    var groupedPlans: [String: [TreatmentPlan]] {
        Dictionary(grouping: treatmentPlans) { plan in
            plan.condition ?? "Unknown Condition"
        }
    }

    // Sort conditions alphabetically
    var sortedConditions: [String] {
        groupedPlans.keys.sorted()
    }

    var body: some View {
        List {
            // Disclaimer Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Read-Only Reference")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Use the web app to add or modify treatment plans")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Treatment Plans by Condition
            if treatmentPlans.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Treatment Plans")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Treatment plans created in the web app will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(sortedConditions, id: \.self) { condition in
                    Section(header: Text(condition).textCase(.none)) {
                        ForEach(groupedPlans[condition] ?? [], id: \.objectID) { plan in
                            NavigationLink(destination: TreatmentPlanDetailView(treatmentPlan: plan)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan.name ?? "Unnamed Plan")
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    if let description = plan.planDescription, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }

                                    // Step count
                                    if let steps = plan.steps as? Set<TreatmentPlanStep> {
                                        let sortedSteps = steps.sorted { $0.stepNumber < $1.stepNumber }
                                        if !sortedSteps.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "list.number")
                                                    .font(.caption2)
                                                Text("\(sortedSteps.count) step\(sortedSteps.count == 1 ? "" : "s")")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(InsetGroupedListStyle())
        #endif
        .navigationTitle("Treatment Plans")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        TreatmentPlansListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
