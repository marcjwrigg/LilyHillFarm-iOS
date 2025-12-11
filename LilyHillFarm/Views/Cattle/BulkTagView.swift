//
//  BulkTagView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct BulkTagView: View {
    let selectedCattle: [Cattle]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var actionType: TagAction = .add
    @State private var tagInput = ""
    @State private var selectedExistingTags: Set<String> = []

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    enum TagAction {
        case add, remove
    }

    // Get all unique tags from selected cattle
    var existingTags: [String] {
        var allTags = Set<String>()
        for cattle in selectedCattle {
            allTags.formUnion(cattle.tagArray)
        }
        return Array(allTags).sorted()
    }

    // Tags to be added (from text input)
    var tagsToAdd: [String] {
        tagInput.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationView {
            Form {
                // Selected Cattle Summary
                Section {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selectedCattle.count) Animals Selected")
                                .font(.headline)
                            Text("Add or remove tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Action Type
                Section("Action") {
                    Picker("Action", selection: $actionType) {
                        Text("Add Tags").tag(TagAction.add)
                        Text("Remove Tags").tag(TagAction.remove)
                    }
                    .pickerStyle(.segmented)
                }

                // Add Tags
                if actionType == .add {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter tags separated by commas")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("e.g., vaccinated, for sale, organic", text: $tagInput)
                                .textFieldStyle(.roundedBorder)

                            if !tagsToAdd.isEmpty {
                                Text("Will add: \(tagsToAdd.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("New Tags")
                    }

                    // Show existing tags as quick add options
                    if !existingTags.isEmpty {
                        Section("Or Select from Existing Tags") {
                            ForEach(existingTags, id: \.self) { tag in
                                Button(action: {
                                    if tagInput.isEmpty {
                                        tagInput = tag
                                    } else {
                                        tagInput += ", \(tag)"
                                    }
                                }) {
                                    HStack {
                                        Text(tag)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                // Remove Tags
                if actionType == .remove {
                    if existingTags.isEmpty {
                        Section {
                            Text("No tags found on selected animals")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } else {
                        Section("Select Tags to Remove") {
                            ForEach(existingTags, id: \.self) { tag in
                                Button(action: {
                                    if selectedExistingTags.contains(tag) {
                                        selectedExistingTags.remove(tag)
                                    } else {
                                        selectedExistingTags.insert(tag)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedExistingTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedExistingTags.contains(tag) ? .blue : .secondary)
                                        Text(tag)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                            }
                        }

                        if !selectedExistingTags.isEmpty {
                            Section {
                                Text("Will remove: \(Array(selectedExistingTags).sorted().joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                // Preview: Show animals and their current tags
                Section("Selected Animals") {
                    ForEach(selectedCattle, id: \.objectID) { cattle in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(cattle.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(cattle.tagNumber ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if !cattle.tagArray.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(cattle.tagArray, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            } else {
                                Text("No tags")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Bulk Tag Management")
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
                    Button(actionType == .add ? "Add Tags" : "Remove Tags") {
                        applyTagChanges()
                    }
                    .disabled((actionType == .add && tagsToAdd.isEmpty) || (actionType == .remove && selectedExistingTags.isEmpty))
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Apply Tag Changes

    private func applyTagChanges() {
        switch actionType {
        case .add:
            guard !tagsToAdd.isEmpty else {
                errorMessage = "Please enter at least one tag"
                showingError = true
                return
            }

            for cattle in selectedCattle {
                cattle.addTags(tagsToAdd)
            }

        case .remove:
            guard !selectedExistingTags.isEmpty else {
                errorMessage = "Please select at least one tag to remove"
                showingError = true
                return
            }

            for cattle in selectedCattle {
                cattle.removeTags(Array(selectedExistingTags))
            }
        }

        // Save changes
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    BulkTagView(selectedCattle: {
        let context = PersistenceController.preview.container.viewContext
        var cattle: [Cattle] = []

        for i in 1...3 {
            let animal = Cattle.create(in: context)
            animal.tagNumber = "LHF-\(String(format: "%03d", i))"
            animal.name = "Sample \(i)"
            animal.tags = ["vaccinated", "organic"].joined(separator: ",")
            cattle.append(animal)
        }

        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
