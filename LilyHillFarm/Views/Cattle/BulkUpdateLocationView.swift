//
//  BulkUpdateLocationView.swift
//  LilyHillFarm
//
//  View for updating location (pastures) for multiple cattle at once
//

import SwiftUI
internal import CoreData

struct BulkUpdateLocationView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pasture.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var pastures: FetchedResults<Pasture>

    @State private var selectedPastures: Set<Pasture> = []
    @State private var showPasturePicker = false
    @State private var updateDate = Date()
    @State private var notes = ""

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            Form {
                // Selected Cattle Summary
                Section("Selected Cattle") {
                    HStack {
                        Text("Count")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(selectedCattle.count)")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedCattle, id: \.objectID) { cattle in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cattle.tagNumber ?? "Unknown")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let name = cattle.name, !name.isEmpty {
                                        Text(name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            }
                        }
                    }
                }

                // Location Selection
                Section("New Location") {
                    MultiSelectDisplay(
                        selectedItems: selectedPastures,
                        itemLabel: { $0.displayValue },
                        placeholder: "Select pastures",
                        onTap: { showPasturePicker = true }
                    )

                    if !selectedPastures.isEmpty {
                        Text("Cattle will be assigned to \(selectedPastures.count) pasture\(selectedPastures.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Update Details
                Section("Update Details") {
                    DatePicker("Update Date", selection: $updateDate, displayedComponents: .date)

                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Summary
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("This will update the location for all \(selectedCattle.count) selected cattle.")
                                .font(.subheadline)
                        }

                        if !selectedPastures.isEmpty {
                            Text("New location: \(selectedPastures.map { $0.name ?? "Unknown" }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Bulk Update Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        updateLocations()
                    }
                    .disabled(selectedPastures.isEmpty)
                }
            }
            .sheet(isPresented: $showPasturePicker) {
                MultiSelectPicker(
                    title: "Select Pastures",
                    items: Array(pastures),
                    selectedItems: $selectedPastures,
                    itemLabel: { $0.displayValue }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Successfully updated location for \(selectedCattle.count) cattle.")
            }
        }
    }

    // MARK: - Update Locations

    private func updateLocations() {
        guard !selectedPastures.isEmpty else {
            errorMessage = "Please select at least one pasture"
            showingError = true
            return
        }

        // Convert selected pastures to UUID array
        let pastureIds = selectedPastures.toUUIDArray()

        // Update each cattle's location
        for cattle in selectedCattle {
            cattle.location = pastureIds as NSArray
            cattle.modifiedAt = Date()

            // Optionally add a note about the location change
            if !notes.isEmpty {
                let locationNote = "Location updated: \(selectedPastures.map { $0.name ?? "Unknown" }.joined(separator: ", "))"
                if let existingNotes = cattle.notes, !existingNotes.isEmpty {
                    cattle.notes = existingNotes + "\n\n[\(formatDate(updateDate))] \(locationNote)\n\(notes)"
                } else {
                    cattle.notes = "[\(formatDate(updateDate))] \(locationNote)\n\(notes)"
                }
            }
        }

        // Update pasture occupancy counts
        updatePastureOccupancy()

        // Save changes
        do {
            try viewContext.save()
            showingSuccess = true
        } catch {
            errorMessage = "Failed to update locations: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func updatePastureOccupancy() {
        // Increment occupancy for selected pastures
        for pasture in selectedPastures {
            pasture.currentOccupancy += Int32(selectedCattle.count)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext

    // Create sample cattle
    let cattle1 = Cattle.create(in: context)
    cattle1.tagNumber = "A001"
    cattle1.name = "Bessie"

    let cattle2 = Cattle.create(in: context)
    cattle2.tagNumber = "A002"
    cattle2.name = "Daisy"

    return BulkUpdateLocationView(selectedCattle: [cattle1, cattle2])
        .environment(\.managedObjectContext, context)
}
