//
//  CattleListView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct CattleListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default)
    private var allCattle: FetchedResults<Cattle>

    @State private var searchText = ""
    @State private var selectedStage: LegacyCattleStage? = nil
    @State private var selectedStatus: CattleStatus = .active
    @State private var selectedLocations: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var showingAddCattle = false
    @State private var showingFilterSheet = false
    @State private var selectionMode = false
    @State private var selectedCattle: Set<NSManagedObjectID> = []
    @State private var showingBulkHealth = false
    @State private var showingBulkPromote = false
    @State private var showingBulkSale = false
    @State private var showingBulkTag = false
    @State private var showingBulkLocation = false
    @State private var showingBulkBreeding = false
    @State private var showingBulkPregnancyCheck = false
    @State private var showingBulkCalving = false

    var filteredCattle: [Cattle] {
        allCattle.filter { cattle in
            // Status filter (now always applied, defaults to active)
            guard cattle.currentStatus == selectedStatus.rawValue else { return false }

            // Stage filter
            if let stage = selectedStage {
                guard cattle.currentStage == stage.rawValue else { return false }
            }

            // Location filter
            if !selectedLocations.isEmpty {
                let cattleLocations = cattle.locationArray
                let hasMatchingLocation = selectedLocations.contains { selectedLoc in
                    cattleLocations.contains(selectedLoc)
                }
                guard hasMatchingLocation else { return false }
            }

            // Tags filter
            if !selectedTags.isEmpty {
                let cattleTags = cattle.tagArray
                let hasMatchingTag = selectedTags.contains { selectedTag in
                    cattleTags.contains(selectedTag)
                }
                guard hasMatchingTag else { return false }
            }

            // Search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let matchesTag = cattle.tagNumber?.lowercased().contains(searchLower) ?? false
                let matchesName = cattle.name?.lowercased().contains(searchLower) ?? false
                let matchesBreed = cattle.breed?.name?.lowercased().contains(searchLower) ?? false
                return matchesTag || matchesName || matchesBreed
            }

            return true
        }
    }

    // Get all unique locations from cattle
    var allLocations: [String] {
        let locations = allCattle.flatMap { $0.locationArray }
        return Array(Set(locations)).sorted()
    }

    // Get all unique tags from cattle
    var allTags: [String] {
        let tags = allCattle.flatMap { $0.tagArray }
        return Array(Set(tags)).sorted()
    }

    var selectedCattleArray: [Cattle] {
        allCattle.filter { selectedCattle.contains($0.objectID) }
    }

    // Check if any filters are active (beyond defaults)
    var hasActiveFilters: Bool {
        !searchText.isEmpty ||
        selectedStage != nil ||
        selectedStatus != .active ||
        !selectedLocations.isEmpty ||
        !selectedTags.isEmpty
    }

    // Clear all filters to defaults
    private func clearAllFilters() {
        searchText = ""
        selectedStage = nil
        selectedStatus = .active
        selectedLocations.removeAll()
        selectedTags.removeAll()
    }

    var body: some View {
        VStack(spacing: 0) {
                // Compact Filters
                VStack(spacing: 8) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        TextField("Search by tag, name, or breed", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.subheadline)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                    .cornerRadius(8)

                    // Stage filter (compact)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            CompactFilterChip(
                                title: "All",
                                isSelected: selectedStage == nil,
                                action: { selectedStage = nil }
                            )

                            ForEach(LegacyCattleStage.allCases) { stage in
                                CompactFilterChip(
                                    title: stage.shortName,
                                    isSelected: selectedStage == stage,
                                    action: { selectedStage = stage }
                                )
                            }
                        }
                    }

                    // Clear filters button (shown when any filters are active)
                    if hasActiveFilters {
                        Button(action: clearAllFilters) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                Text("Clear All Filters")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white)

                Divider()

                // Results count
                HStack {
                    Text("\(filteredCattle.count) cattle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()

                    if selectionMode && !selectedCattle.isEmpty {
                        Text("\(selectedCattle.count) selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Cattle list
                if filteredCattle.isEmpty {
                    EmptyStateView(
                        icon: "pawprint.circle",
                        title: searchText.isEmpty ? "No cattle found" : "No results",
                        message: searchText.isEmpty ? "Add your first cattle to get started" : "Try adjusting your filters"
                    )
                } else {
                    List {
                        ForEach(filteredCattle, id: \.objectID) { cattle in
                            if selectionMode {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        toggleSelection(cattle)
                                    }) {
                                        Image(systemName: selectedCattle.contains(cattle.objectID) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedCattle.contains(cattle.objectID) ? .blue : .secondary)
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)

                                    CattleRowView(cattle: cattle)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(cattle)
                                }
                            } else {
                                NavigationLink(destination: CattleDetailView(cattle: cattle)) {
                                    CattleRowView(cattle: cattle)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                // Bulk Action Bar
                if selectionMode && !selectedCattle.isEmpty {
                    VStack(spacing: 0) {
                        Divider()

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                Button(action: {
                                    showingBulkHealth = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "heart.text.square")
                                            .font(.title3)
                                        Text("Health")
                                            .font(.caption2)
                                    }
                                }

                                Button(action: {
                                    showingBulkPromote = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "arrow.up.circle")
                                            .font(.title3)
                                        Text("Promote")
                                            .font(.caption2)
                                    }
                                }

                                Button(action: {
                                    showingBulkSale = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "dollarsign.circle")
                                            .font(.title3)
                                        Text("Sale")
                                            .font(.caption2)
                                    }
                                }

                                Button(action: {
                                    showingBulkTag = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "tag.fill")
                                            .font(.title3)
                                        Text("Tags")
                                            .font(.caption2)
                                    }
                                }

                                Button(action: {
                                    showingBulkLocation = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "map")
                                            .font(.title3)
                                        Text("Location")
                                            .font(.caption2)
                                    }
                                }

                                Button(action: {
                                    showingBulkBreeding = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "heart.circle")
                                            .font(.title3)
                                        Text("Breeding")
                                            .font(.caption2)
                                    }
                                }

                                Button(action: {
                                    showingBulkPregnancyCheck = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "stethoscope")
                                            .font(.title3)
                                        Text("Preg Check")
                                            .font(.caption2)
                                    }
                                }

                                Button(action: {
                                    showingBulkCalving = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "figure.and.child.holdinghands")
                                            .font(.title3)
                                        Text("Calving")
                                            .font(.caption2)
                                    }
                                }

                                Divider()
                                    .frame(height: 40)

                                Button(action: {
                                    selectedCattle.removeAll()
                                }) {
                                    Text("Deselect All")
                                        .font(.caption)
                                }
                            }
                            .padding()
                        }
                        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                    }
                }
            }
            .navigationTitle("Herd")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectionMode {
                        Button("Done") {
                            selectionMode = false
                            selectedCattle.removeAll()
                        }
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    if selectionMode {
                        Button("Done") {
                            selectionMode = false
                            selectedCattle.removeAll()
                        }
                    }
                }
                #endif

                ToolbarItem(placement: .automatic) {
                    if !selectionMode {
                        Button(action: { showingFilterSheet = true }) {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        if selectionMode {
                            selectionMode = false
                            selectedCattle.removeAll()
                        } else {
                            selectionMode = true
                        }
                    }) {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    if !selectionMode {
                        Button(action: { showingAddCattle = true }) {
                            Label("Add Cattle", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddCattle) {
                AddCattleView()
            }
            .sheet(isPresented: $showingBulkHealth) {
                BulkHealthRecordView(selectedCattle: selectedCattleArray)
            }
            .sheet(isPresented: $showingBulkPromote) {
                BulkPromoteStageView(selectedCattle: selectedCattleArray)
            }
            .sheet(isPresented: $showingBulkSale) {
                BulkSaleView(selectedCattle: selectedCattleArray)
            }
            .sheet(isPresented: $showingBulkTag) {
                BulkTagView(selectedCattle: selectedCattleArray)
            }
            .sheet(isPresented: $showingBulkBreeding) {
                BulkBreedingView(selectedCattle: selectedCattleArray)
            }
            .sheet(isPresented: $showingBulkPregnancyCheck) {
                BulkPregnancyCheckView(selectedCattle: selectedCattleArray)
            }
            .sheet(isPresented: $showingBulkCalving) {
                BulkCalvingView(selectedCattle: selectedCattleArray)
            }
            .sheet(isPresented: $showingBulkLocation) {
                BulkUpdateLocationView(selectedCattle: selectedCattleArray)
            }
            .sheet(isPresented: $showingFilterSheet) {
                CattleFilterSheet(
                    selectedStatus: $selectedStatus,
                    selectedLocations: $selectedLocations,
                    selectedTags: $selectedTags,
                    allLocations: allLocations,
                    allTags: allTags
                )
            }
    }

    // MARK: - Selection Helpers

    private func toggleSelection(_ cattle: Cattle) {
        if selectedCattle.contains(cattle.objectID) {
            selectedCattle.remove(cattle.objectID)
        } else {
            selectedCattle.insert(cattle.objectID)
        }
    }
}

// MARK: - Filter Sheet

struct CattleFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStatus: CattleStatus
    @Binding var selectedLocations: Set<String>
    @Binding var selectedTags: Set<String>
    let allLocations: [String]
    let allTags: [String]

    var body: some View {
        NavigationStack {
            Form {
                // Status Filter
                Section("Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(CattleStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Location Filter
                if !allLocations.isEmpty {
                    Section("Location") {
                        ForEach(allLocations, id: \.self) { location in
                            Toggle(location, isOn: Binding(
                                get: { selectedLocations.contains(location) },
                                set: { isOn in
                                    if isOn {
                                        selectedLocations.insert(location)
                                    } else {
                                        selectedLocations.remove(location)
                                    }
                                }
                            ))
                        }
                    }
                }

                // Tags Filter
                if !allTags.isEmpty {
                    Section("Tags") {
                        ForEach(allTags, id: \.self) { tag in
                            Toggle(tag, isOn: Binding(
                                get: { selectedTags.contains(tag) },
                                set: { isOn in
                                    if isOn {
                                        selectedTags.insert(tag)
                                    } else {
                                        selectedTags.remove(tag)
                                    }
                                }
                            ))
                        }
                    }
                }

                // Reset Filters
                Section {
                    Button("Reset All Filters") {
                        selectedStatus = .active
                        selectedLocations.removeAll()
                        selectedTags.removeAll()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - macOS Cattle List View

#if os(macOS)
struct MacOSCattleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedCattle: Cattle?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        animation: .default)
    private var allCattle: FetchedResults<Cattle>

    @State private var searchText = ""
    @State private var selectedStage: LegacyCattleStage? = nil
    @State private var selectedStatus: CattleStatus? = .active
    @State private var showingAddCattle = false
    @State private var selectionMode = false
    @State private var selectedCattleSet: Set<NSManagedObjectID> = []
    @State private var showingBulkHealth = false
    @State private var showingBulkPromote = false
    @State private var showingBulkSale = false
    @State private var showingBulkTag = false
    @State private var showingBulkLocation = false
    @State private var showingBulkBreeding = false
    @State private var showingBulkPregnancyCheck = false
    @State private var showingBulkCalving = false

    var filteredCattle: [Cattle] {
        allCattle.filter { cattle in
            // Status filter
            if let status = selectedStatus {
                guard cattle.currentStatus == status.rawValue else { return false }
            }

            // Stage filter
            if let stage = selectedStage {
                guard cattle.currentStage == stage.rawValue else { return false }
            }

            // Search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let matchesTag = cattle.tagNumber?.lowercased().contains(searchLower) ?? false
                let matchesName = cattle.name?.lowercased().contains(searchLower) ?? false
                let matchesBreed = cattle.breed?.name?.lowercased().contains(searchLower) ?? false
                return matchesTag || matchesName || matchesBreed
            }

            return true
        }
    }

    var selectedCattleArray: [Cattle] {
        allCattle.filter { selectedCattleSet.contains($0.objectID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filters
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by tag, name, or breed", text: $searchText)
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

                // Stage filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All Stages",
                            isSelected: selectedStage == nil,
                            action: { selectedStage = nil }
                        )

                        ForEach(LegacyCattleStage.allCases) { stage in
                            FilterChip(
                                title: stage.displayName,
                                isSelected: selectedStage == stage,
                                action: { selectedStage = stage }
                            )
                        }
                    }
                }

                // Status filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CattleStatus.allCases) { status in
                            FilterChip(
                                title: status.rawValue,
                                isSelected: selectedStatus == status,
                                action: { selectedStatus = status },
                                style: status == .active ? .primary : .secondary
                            )
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)

            Divider()

            // Results count
            HStack {
                Text("\(filteredCattle.count) cattle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()

                if selectionMode && !selectedCattleSet.isEmpty {
                    Text("\(selectedCattleSet.count) selected")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Cattle list
            if filteredCattle.isEmpty {
                EmptyStateView(
                    icon: "pawprint.circle",
                    title: searchText.isEmpty ? "No cattle found" : "No results",
                    message: searchText.isEmpty ? "Add your first cattle to get started" : "Try adjusting your filters"
                )
            } else {
                List(filteredCattle, id: \.objectID, selection: $selectedCattle) { cattle in
                    if selectionMode {
                        HStack(spacing: 12) {
                            Button(action: {
                                toggleSelection(cattle)
                            }) {
                                Image(systemName: selectedCattleSet.contains(cattle.objectID) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedCattleSet.contains(cattle.objectID) ? .blue : .secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)

                            CattleRowView(cattle: cattle)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(cattle)
                        }
                        .tag(cattle)
                    } else {
                        CattleRowView(cattle: cattle)
                            .tag(cattle)
                    }
                }
                .listStyle(.plain)
            }

            // Bulk Action Bar
            if selectionMode && !selectedCattleSet.isEmpty {
                VStack(spacing: 0) {
                    Divider()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            Button(action: {
                                showingBulkHealth = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "heart.text.square")
                                        .font(.title3)
                                    Text("Health")
                                        .font(.caption2)
                                }
                            }

                            Button(action: {
                                showingBulkPromote = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.title3)
                                    Text("Promote")
                                        .font(.caption2)
                                }
                            }

                            Button(action: {
                                showingBulkSale = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "dollarsign.circle")
                                        .font(.title3)
                                    Text("Sale")
                                        .font(.caption2)
                                }
                            }

                            Button(action: {
                                showingBulkTag = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.title3)
                                    Text("Tags")
                                        .font(.caption2)
                                }
                            }

                            Button(action: {
                                showingBulkBreeding = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "heart.circle")
                                        .font(.title3)
                                    Text("Breeding")
                                        .font(.caption2)
                                }
                            }

                            Button(action: {
                                showingBulkPregnancyCheck = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "stethoscope")
                                        .font(.title3)
                                    Text("Preg Check")
                                        .font(.caption2)
                                }
                            }

                            Button(action: {
                                showingBulkCalving = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "figure.and.child.holdinghands")
                                        .font(.title3)
                                    Text("Calving")
                                        .font(.caption2)
                                }
                            }

                            Divider()
                                .frame(height: 40)

                            Button(action: {
                                selectedCattleSet.removeAll()
                            }) {
                                Text("Deselect All")
                                    .font(.caption)
                            }
                        }
                        .padding()
                    }
                    .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                }
            }
        }
        .navigationTitle("Herd")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if selectionMode {
                    Button("Done") {
                        selectionMode = false
                        selectedCattleSet.removeAll()
                    }
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    if selectionMode {
                        selectionMode = false
                        selectedCattleSet.removeAll()
                    } else {
                        selectionMode = true
                    }
                }) {
                    Label("Select", systemImage: "checkmark.circle")
                }
            }

            ToolbarItem(placement: .automatic) {
                if !selectionMode {
                    Button(action: { showingAddCattle = true }) {
                        Label("Add Cattle", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCattle) {
            AddCattleView()
        }
        .sheet(isPresented: $showingBulkHealth) {
            BulkHealthRecordView(selectedCattle: selectedCattleArray)
        }
        .sheet(isPresented: $showingBulkPromote) {
            BulkPromoteStageView(selectedCattle: selectedCattleArray)
        }
        .sheet(isPresented: $showingBulkSale) {
            BulkSaleView(selectedCattle: selectedCattleArray)
        }
        .sheet(isPresented: $showingBulkTag) {
            BulkTagView(selectedCattle: selectedCattleArray)
        }
        .sheet(isPresented: $showingBulkBreeding) {
            BulkBreedingView(selectedCattle: selectedCattleArray)
        }
        .sheet(isPresented: $showingBulkPregnancyCheck) {
            BulkPregnancyCheckView(selectedCattle: selectedCattleArray)
        }
        .sheet(isPresented: $showingBulkCalving) {
            BulkCalvingView(selectedCattle: selectedCattleArray)
        }
    }

    // MARK: - Selection Helpers

    private func toggleSelection(_ cattle: Cattle) {
        if selectedCattleSet.contains(cattle.objectID) {
            selectedCattleSet.remove(cattle.objectID)
        } else {
            selectedCattleSet.insert(cattle.objectID)
        }
    }
}
#endif

#Preview {
    CattleListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
