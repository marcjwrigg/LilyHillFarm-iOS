//
//  OffspringListView.swift
//  LilyHillFarm
//
//  View for displaying offspring of a cattle
//

import SwiftUI
internal import CoreData

struct OffspringListView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext

    var offspring: [Cattle] {
        // Determine offspring based on parent's sex
        let allOffspring = cattle.offspringArray + cattle.offspringAsSire
        return allOffspring.sorted {
            ($0.dateOfBirth ?? Date.distantPast) > ($1.dateOfBirth ?? Date.distantPast)
        }
    }

    var parentRole: String {
        // Determine if this animal is a dam or sire
        if cattle.sex == "Cow" || cattle.sex == "Heifer" {
            return "Dam"
        } else {
            return "Sire"
        }
    }

    var body: some View {
        Group {
            if offspring.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "heart.circle")
                        .font(.system(size: 70))
                        .foregroundColor(.blue.opacity(0.3))

                    VStack(spacing: 8) {
                        Text("No Offspring")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("No calves recorded for this animal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Summary header
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Offspring")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(offspring.count)")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Role")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(parentRole)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Offspring list
                    Section {
                        ForEach(offspring, id: \.objectID) { calf in
                            NavigationLink(destination: CattleDetailView(cattle: calf)) {
                                OffspringRowView(calf: calf, parent: cattle)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Offspring")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Offspring Row View

struct OffspringRowView: View {
    @ObservedObject var calf: Cattle
    @ObservedObject var parent: Cattle

    var otherParent: Cattle? {
        // Show the other parent (not the current parent we're viewing from)
        if calf.dam?.objectID == parent.objectID {
            return calf.sire
        } else if calf.sire?.objectID == parent.objectID {
            return calf.dam
        }
        return nil
    }

    var otherParentRole: String {
        if calf.dam?.objectID == parent.objectID {
            return "Sire"
        } else {
            return "Dam"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Animal Icon with sex indicator
            ZStack {
                Circle()
                    .fill(sexColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: sexIcon)
                    .font(.system(size: 24))
                    .foregroundColor(sexColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                // Name/Tag
                Text(calf.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Stage and Age
                HStack(spacing: 8) {
                    if let stage = calf.currentStage {
                        StageBadge(stage: stage)
                    }

                    Text(calf.age)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Other parent info
                if let otherParent = otherParent {
                    HStack(spacing: 4) {
                        Text("\(otherParentRole):")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(otherParent.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                }

                // Date of birth
                if let dob = calf.dateOfBirth {
                    Text("Born: \(formatDate(dob))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var sexIcon: String {
        if calf.sex == "Bull" || calf.sex == "Steer" {
            return "rectangle.fill"
        } else {
            return "circle.fill"
        }
    }

    private var sexColor: Color {
        if calf.sex == "Bull" {
            return .blue
        } else if calf.sex == "Cow" || calf.sex == "Heifer" {
            return .pink
        } else {
            return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        OffspringListView(cattle: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            cattle.tagNumber = "LHF-001"
            cattle.name = "Bessie"
            cattle.sex = "Cow"
            return cattle
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
