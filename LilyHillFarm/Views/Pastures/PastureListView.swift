//
//  PastureListView.swift
//  LilyHillFarm
//
//  View for listing and managing pastures
//

import SwiftUI
internal import CoreData

struct PastureListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pasture.name, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default)
    private var pastures: FetchedResults<Pasture>

    @State private var searchText = ""

    var filteredPastures: [Pasture] {
        var filtered = Array(pastures)

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { pasture in
                (pasture.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (pasture.pastureType?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return filtered
    }

    private var totalAcreage: Double {
        pastures.reduce(0) { $0 + $1.acreage }
    }

    private var totalForageAcres: Double {
        pastures.reduce(0) { $0 + $1.forageAcres }
    }

    private var totalAnimals: Int {
        // Query all cattle with location set (not deceased, sold, or processed)
        let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "location != nil AND currentStatus != %@ AND currentStatus != %@ AND currentStatus != %@",
            CattleStatus.deceased.rawValue,
            CattleStatus.sold.rawValue,
            CattleStatus.processed.rawValue
        )

        do {
            let cattleWithLocation = try viewContext.fetch(fetchRequest)
            return cattleWithLocation.count
        } catch {
            print("Error counting total animals: \(error)")
            return 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats cards - 2x2 grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                CompactStatCard(
                    title: "Pastures",
                    value: "\(pastures.count)",
                    icon: "map",
                    color: .blue
                )

                CompactStatCard(
                    title: "Total Acres",
                    value: String(format: "%.1f", totalAcreage),
                    icon: "mappin.circle",
                    color: .green
                )

                CompactStatCard(
                    title: "Forage Acres",
                    value: String(format: "%.1f", totalForageAcres),
                    icon: "leaf.fill",
                    color: .green
                )

                CompactStatCard(
                    title: "Animals",
                    value: "\(totalAnimals)",
                    icon: "figure.walk",
                    color: .orange
                )
            }
            .padding()
            .background(Color(.systemGroupedBackground))

            if filteredPastures.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredPastures, id: \.objectID) { pasture in
                        NavigationLink(destination: PastureDetailView(pasture: pasture)) {
                            PastureRowView(pasture: pasture)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Pastures")
        .searchable(text: $searchText, prompt: "Search pastures")
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Pastures Found")
                .font(.headline)

            Text("No pastures in the system.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pasture Row View

struct PastureRowView: View {
    @ObservedObject var pasture: Pasture
    @Environment(\.managedObjectContext) private var viewContext

    private var actualAnimalCount: Int {
        // Fetch all cattle and filter by location array containing pasture name
        let fetchRequest: NSFetchRequest<Cattle> = Cattle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "deletedAt == nil AND location != nil")

        do {
            let allCattle = try viewContext.fetch(fetchRequest)
            // Filter cattle whose locationArray contains this pasture's name
            let count = allCattle.filter { cattle in
                cattle.locationArray.contains(pasture.name ?? "")
            }.count
            return count
        } catch {
            print("Error counting animals: \(error)")
            return 0
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(pasture.name ?? "Unknown")
                    .font(.headline)

                HStack(spacing: 16) {
                    Text("Total: \(String(format: "%.1f", pasture.acreage)) ac")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Forage: \(String(format: "%.1f", pasture.forageAcres)) ac")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Animals: \(actualAnimalCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Circle()
                .fill(conditionColor)
                .frame(width: 12, height: 12)
        }
        .padding(.vertical, 8)
    }

    private var conditionColor: Color {
        guard let condition = pasture.pastureCondition else { return .gray }

        switch condition.lowercased() {
        case "excellent":
            return .green
        case "good":
            return .blue
        case "fair":
            return .orange
        case "poor":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    PastureListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
