//
//  CattleRowView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct CattleRowView: View {
    @ObservedObject var cattle: Cattle

    var body: some View {
        HStack(spacing: 10) {
            // Stage badge
            if let stage = cattle.currentStage {
                StageBadge(stage: stage)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
            }

            // Cattle info - 2 rows
            VStack(alignment: .leading, spacing: 3) {
                // Row 1: Tag Number - Name - Breed - Sex - Stage - Age
                HStack(spacing: 4) {
                    Text(cattle.tagNumber ?? "No Tag")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let name = cattle.name, !name.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(name)
                            .font(.subheadline)
                    }

                    if let breed = cattle.breed?.name {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(breed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let sex = cattle.sex {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(sex)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let stage = cattle.currentStage {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(stage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(cattle.age)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)

                // Row 2: Tags & Location
                HStack(spacing: 6) {
                    // Tags
                    if !cattle.tagArray.isEmpty {
                        HStack(spacing: 3) {
                            ForEach(cattle.tagArray, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 9))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(3)
                            }
                        }
                    }

                    // Location
                    if let location = cattle.primaryLocation, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 8))
                            Text(location)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.green)
                    }
                }
                .lineLimit(1)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Stage Badge Component

struct StageBadge: View {
    let stage: String

    var badgeColor: Color {
        guard let cattleStage = LegacyCattleStage(rawValue: stage) else {
            return .gray
        }

        switch cattleStage {
        case .calf:
            return .orange
        case .weanling:
            return .blue
        case .stocker:
            return .purple
        case .feeder:
            return .yellow
        case .breeding:
            return .green
        case .processed:
            return .gray
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(badgeColor)
                .frame(width: 24, height: 24)

            Text(String(stage.prefix(1)))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    List {
        CattleRowView(cattle: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            cattle.tagNumber = "LHF-001"
            cattle.name = "Bessie"
            cattle.sex = CattleSex.cow.rawValue
            cattle.color = "Black"
            cattle.currentStage = LegacyCattleStage.weanling.rawValue
            cattle.dateOfBirth = Calendar.current.date(byAdding: .month, value: -8, to: Date())
            return cattle
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
