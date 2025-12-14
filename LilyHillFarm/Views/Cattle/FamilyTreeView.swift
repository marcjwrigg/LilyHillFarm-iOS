//
//  FamilyTreeView.swift
//  LilyHillFarm
//
//  Family tree view showing pedigree and offspring hierarchy
//

import SwiftUI
@preconcurrency internal import CoreData

struct FamilyTreeView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showInactive = true

    // Fetch offspring
    @FetchRequest private var offspring: FetchedResults<Cattle>

    init(cattle: Cattle) {
        self.cattle = cattle

        // Initialize FetchRequest for offspring based on sex
        let predicate: NSPredicate
        if cattle.sex == "Bull" {
            predicate = NSPredicate(format: "sire == %@ AND deletedAt == nil", cattle)
        } else {
            predicate = NSPredicate(format: "dam == %@ AND deletedAt == nil", cattle)
        }

        _offspring = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.dateOfBirth, ascending: false)],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Grandparents section
                    if hasGrandparents {
                        grandparentsSection
                    }

                    // Parents section
                    if hasParents {
                        parentsSection
                    }

                    // Current animal (always shown)
                    currentAnimalSection

                    // Offspring section
                    if offspring.count > 0 {
                        offspringSection
                    }
                }
                .padding()
            }
            .navigationTitle("Family Tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var hasGrandparents: Bool {
        (cattle.sire?.sire != nil || cattle.sire?.dam != nil ||
         cattle.dam?.sire != nil || cattle.dam?.dam != nil)
    }

    private var hasParents: Bool {
        cattle.sire != nil || cattle.dam != nil
    }

    private var visibleOffspring: [Cattle] {
        offspring.filter { calf in
            showInactive || calf.currentStatus == CattleStatus.active.rawValue
        }
    }

    private var inactiveCount: Int {
        offspring.filter { $0.currentStatus != CattleStatus.active.rawValue }.count
    }

    // MARK: - View Sections

    private var grandparentsSection: some View {
        VStack(spacing: 12) {
            Text("Grandparents")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Paternal grandparents
                AnimalCard(
                    title: "Paternal Grandfather",
                    animal: cattle.sire?.sire,
                    color: .blue
                )

                AnimalCard(
                    title: "Paternal Grandmother",
                    animal: cattle.sire?.dam,
                    color: .blue
                )

                // Maternal grandparents
                AnimalCard(
                    title: "Maternal Grandfather",
                    animal: cattle.dam?.sire,
                    color: .pink
                )

                AnimalCard(
                    title: "Maternal Grandmother",
                    animal: cattle.dam?.dam,
                    color: .pink
                )
            }

            // Connecting line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 24)
        }
    }

    private var parentsSection: some View {
        VStack(spacing: 12) {
            Text("Parents")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                AnimalCard(
                    title: "Sire (Father)",
                    animal: cattle.sire,
                    color: .blue,
                    isLarge: true
                )

                AnimalCard(
                    title: "Dam (Mother)",
                    animal: cattle.dam,
                    color: .pink,
                    isLarge: true
                )
            }

            // Connecting line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 24)
        }
    }

    private var currentAnimalSection: some View {
        VStack(spacing: 12) {
            Text("Current Animal")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#\(cattle.tagNumber ?? "N/A")")
                            .font(.title2)
                            .fontWeight(.bold)

                        if let name = cattle.name {
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 8) {
                            if let stage = cattle.currentStage {
                                Text(LegacyCattleStage(rawValue: stage)?.displayName ?? stage)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }

                            Text("\(cattle.sex ?? "Unknown") • \(cattle.breed?.name ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if let dob = cattle.dateOfBirth {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Age")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(cattle.age)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: 2)
            )
        }
    }

    private var offspringSection: some View {
        VStack(spacing: 12) {
            // Connecting line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 24)

            HStack {
                Text("Offspring (\(visibleOffspring.count)\(showInactive ? "" : " active"))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                if inactiveCount > 0 {
                    Toggle(showInactive ? "Hide inactive" : "Show inactive (\(inactiveCount))", isOn: $showInactive)
                        .font(.caption2)
                        .toggleStyle(.switch)
                        .labelsHidden()

                    Text(showInactive ? "Hide inactive" : "Show inactive (\(inactiveCount))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if visibleOffspring.isEmpty {
                Text("No \(showInactive ? "" : "active ")offspring")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(visibleOffspring, id: \.objectID) { calf in
                        OffspringCard(animal: calf)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct AnimalCard: View {
    let title: String
    let animal: Cattle?
    let color: Color
    var isLarge: Bool = false

    var body: some View {
        if let animal = animal {
            NavigationLink(destination: CattleDetailView(cattle: animal)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(color)

                    Text("#\(animal.tagNumber ?? "N/A")")
                        .font(isLarge ? .subheadline : .caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let name = animal.name {
                        Text(name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(isLarge ? 12 : 8)
                .background(color.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: isLarge ? 2 : 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text("Unknown")
                    .font(isLarge ? .subheadline : .caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isLarge ? 12 : 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct OffspringCard: View {
    let animal: Cattle

    var body: some View {
        NavigationLink(destination: CattleDetailView(cattle: animal)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(animal.tagNumber ?? "N/A")")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Spacer()

                    if animal.currentStatus != CattleStatus.active.rawValue {
                        Text(animal.currentStatus ?? "")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }

                if let name = animal.name {
                    Text(name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    if let stage = animal.currentStage {
                        Text(LegacyCattleStage(rawValue: stage)?.displayName ?? stage)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(stageColor(for: stage).opacity(0.2))
                            .foregroundColor(stageColor(for: stage))
                            .cornerRadius(4)
                    }

                    Text(animal.sex ?? "Unknown")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let dob = animal.dateOfBirth {
                    Text(dob, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(animal.currentStatus == CattleStatus.active.rawValue ? Color.gray.opacity(0.05) : Color.gray.opacity(0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(animal.currentStatus == CattleStatus.active.rawValue ? 1.0 : 0.6)
    }

    private func stageColor(for stage: String) -> Color {
        switch stage {
        case "Calf": return .blue
        case "Weanling": return .purple
        case "Stocker": return .indigo
        case "Feeder": return .cyan
        case "Breeding": return .green
        case "Processed": return .gray
        default: return .gray
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let cattle = Cattle.create(in: context)
    cattle.tagNumber = "001"
    cattle.name = "Bessie"
    cattle.sex = "Cow"

    return FamilyTreeView(cattle: cattle)
        .environment(\.managedObjectContext, context)
}
