//
//  CattlePickerView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct CattlePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCattle: Cattle?
    @Binding var showingAddRecord: Bool

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "currentStatus == %@", CattleStatus.active.rawValue),
        animation: .default)
    private var activeCattle: FetchedResults<Cattle>

    @State private var searchText = ""

    var filteredCattle: [Cattle] {
        if searchText.isEmpty {
            return Array(activeCattle)
        } else {
            let searchLower = searchText.lowercased()
            return activeCattle.filter { cattle in
                let matchesTag = cattle.tagNumber?.lowercased().contains(searchLower) ?? false
                let matchesName = cattle.name?.lowercased().contains(searchLower) ?? false
                return matchesTag || matchesName
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search cattle", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                .cornerRadius(10)
                .padding()

                Divider()

                // Cattle list
                if filteredCattle.isEmpty {
                    EmptyStateView(
                        icon: "pawprint.circle",
                        title: "No cattle found",
                        message: searchText.isEmpty ? "Add cattle to your herd first" : "No matching cattle"
                    )
                } else {
                    List {
                        ForEach(filteredCattle, id: \.objectID) { cattle in
                            Button(action: {
                                selectCattle(cattle)
                            }) {
                                HStack(spacing: 12) {
                                    // Photo or placeholder
                                    if let photo = cattle.primaryPhoto,
                                       let thumbnailImage = photo.thumbnailImage {
                                        #if os(iOS)
                                        Image(uiImage: thumbnailImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        #elseif os(macOS)
                                        Image(nsImage: thumbnailImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        #endif
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.secondary)
                                                    .font(.caption)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cattle.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text(cattle.tagNumber ?? "No Tag")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if let breed = cattle.breed?.name {
                                            Text(breed)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Cattle")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Select Cattle

    private func selectCattle(_ cattle: Cattle) {
        selectedCattle = cattle
        dismiss()
        // Small delay to ensure the picker dismisses before showing the add record sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingAddRecord = true
        }
    }
}

#Preview {
    CattlePickerView(
        selectedCattle: .constant(nil),
        showingAddRecord: .constant(false)
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
