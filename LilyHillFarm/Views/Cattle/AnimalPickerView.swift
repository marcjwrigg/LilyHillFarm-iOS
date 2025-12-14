//
//  AnimalPickerView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct AnimalPickerView: View {
    let cattle: [Cattle]
    @Binding var selectedCattle: Cattle?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredCattle: [Cattle] {
        if searchText.isEmpty {
            return cattle
        }
        return cattle.filter { animal in
            let tagMatch = animal.tagNumber?.localizedCaseInsensitiveContains(searchText) ?? false
            let nameMatch = animal.name?.localizedCaseInsensitiveContains(searchText) ?? false
            return tagMatch || nameMatch
        }
    }

    var body: some View {
        List(filteredCattle, id: \.objectID) { animal in
            Button(action: {
                selectedCattle = animal
                dismiss()
            }) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: "pawprint.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#\(animal.tagNumber ?? "Unknown")")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let name = animal.name, !name.isEmpty {
                            Text(name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 8) {
                            if let stage = animal.currentStage {
                                Text(stage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let sex = animal.sex {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(sex)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Search by tag or name")
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AnimalPickerView(
            cattle: {
                let context = PersistenceController.preview.container.viewContext
                return (0..<5).map { i in
                    let cattle = Cattle.create(in: context)
                    cattle.tagNumber = "A\(100 + i)"
                    cattle.name = "Animal \(i + 1)"
                    cattle.currentStage = LegacyCattleStage.allCases.randomElement()?.rawValue
                    cattle.sex = CattleSex.allCases.randomElement()?.rawValue
                    return cattle
                }
            }(),
            selectedCattle: .constant(nil)
        )
        .navigationTitle("Select Animal")
        .navigationBarTitleDisplayMode(.inline)
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
