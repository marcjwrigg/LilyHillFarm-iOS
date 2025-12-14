//
//  PastureDetailView.swift
//  LilyHillFarm
//
//  Detailed view of a pasture with all information
//

import SwiftUI
internal import CoreData
import MapKit

struct PastureDetailView: View {
    @ObservedObject var pasture: Pasture
    @Environment(\.managedObjectContext) private var viewContext

    @State private var region: MKCoordinateRegion?
    @State private var boundaryPolygon: MKPolygon?
    @State private var foragePolygon: MKPolygon?

    // Section expansion states
    @State private var isBasicInfoExpanded = true
    @State private var isCapacityExpanded = true
    @State private var isForageExpanded = true
    @State private var isGrazingExpanded = true
    @State private var isNotesExpanded = true
    @State private var isMetadataExpanded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with name and condition badge
                headerSection

                // Quick Stats Grid (6 cards)
                quickStatsSection

                // Map section (only show if we have valid coordinates AND boundary data)
                if hasValidMapData {
                    mapSection
                } else if pasture.centerLat != 0 && pasture.centerLng != 0 {
                    // Show center point only if we have center but no boundary
                    simpleMapSection
                }

                // Details Card
                InfoCard(title: "Details", isExpanded: $isBasicInfoExpanded) {
                    if let fencing = pasture.fencingType, !fencing.isEmpty {
                        InfoRow(label: "Fencing", value: self.formatFieldValue(fencing), icon: "fence")
                    }
                    if let water = pasture.waterSource, !water.isEmpty {
                        InfoRow(label: "Water Source", value: self.formatFieldValue(water), icon: "drop.fill")
                    }
                    if let forageType = pasture.forageType, !forageType.isEmpty {
                        InfoRow(label: "Forage Type", value: self.formatFieldValue(forageType), icon: "leaf.fill")
                    }
                    if pasture.forageAcres > 0 {
                        InfoRow(label: "Forage Acreage", value: String(format: "%.2f acres", pasture.forageAcres), icon: "map")
                    }
                    if pasture.restPeriodDays > 0 {
                        InfoRow(label: "Rest Period", value: "\(pasture.restPeriodDays) days", icon: "calendar")
                    }
                    if let notes = pasture.notes, !notes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }

                // Tasks Card
                tasksSection

                // Activity Logs Card
                logsSection

                // Animals Card
                animalsSection
            }
            .padding()
        }
        .navigationTitle(pasture.name ?? "Pasture")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupMapRegion()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pasture.name ?? "Unknown")
                        .font(.title)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        Text(self.formatFieldValue(pasture.pastureType ?? "Unknown"))
                        Text("•")
                        if pasture.acreage > 0 {
                            Text(String(format: "%.1f acres", pasture.acreage))
                        }
                        if pasture.forageAcres > 0 {
                            Text("•")
                            Text(String(format: "%.1f forage acres", pasture.forageAcres))
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Condition badge
                if let condition = pasture.pastureCondition, !condition.isEmpty {
                    Text(condition.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(conditionColor.opacity(0.2))
                        .foregroundColor(conditionColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    // MARK: - Quick Stats Section

    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            QuickStatCard(
                title: "Total Acreage",
                value: pasture.acreage > 0 ? String(format: "%.1f", pasture.acreage) : "—",
                icon: "map",
                iconColor: .blue
            )

            QuickStatCard(
                title: "Forage Acreage",
                value: pasture.forageAcres > 0 ? String(format: "%.1f", pasture.forageAcres) : "—",
                icon: "leaf.fill",
                iconColor: .green
            )

            QuickStatCard(
                title: "Current Animals",
                value: "\(pastureAnimals.count)",
                icon: "figure.walk",
                iconColor: .gray
            )

            QuickStatCard(
                title: "Capacity",
                value: pasture.carryingCapacity > 0 ? "\(pasture.carryingCapacity)" : "—",
                icon: "chart.bar",
                iconColor: .gray
            )

            QuickStatCard(
                title: "Utilization",
                value: pasture.carryingCapacity > 0 ? String(format: "%.0f%%", (Double(pastureAnimals.count) / Double(pasture.carryingCapacity)) * 100) : "—",
                icon: "chart.line.uptrend.xyaxis",
                iconColor: occupancyColor
            )

            QuickStatCard(
                title: "Last Grazed",
                value: pasture.lastGrazedDate != nil ? formatDate(pasture.lastGrazedDate!) : "—",
                icon: "calendar",
                iconColor: .gray
            )
        }
    }

    // MARK: - Animals Section

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default
    )
    private var allCattle: FetchedResults<Cattle>

    private var pastureAnimals: [Cattle] {
        guard let pastureName = pasture.name else { return [] }
        return allCattle.filter { cattle in
            cattle.locationArray.contains(pastureName)
        }
    }

    private var animalsSection: some View {
        InfoCard(title: "Animals (\(pastureAnimals.count))", isExpanded: $isCapacityExpanded) {
            if pastureAnimals.isEmpty {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.secondary)
                    Text("No animals in this pasture")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(Array(pastureAnimals.enumerated()), id: \.element.objectID) { index, cattle in
                    NavigationLink(destination: CattleDetailView(cattle: cattle)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cattle.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                if let breedName = cattle.breed?.name, !breedName.isEmpty {
                                    Text(breedName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if let sex = cattle.sex, !sex.isEmpty {
                                Text(sex)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if index < pastureAnimals.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Tasks Section

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default
    )
    private var allTasks: FetchedResults<Task>

    private var pastureTasks: [Task] {
        guard let pastureId = pasture.id else { return [] }
        return allTasks.filter { task in
            guard let pastureIds = task.pastureIds as? [UUID] else { return false }
            return pastureIds.contains(pastureId)
        }
    }

    private var tasksSection: some View {
        InfoCard(title: "Tasks (\(pastureTasks.count))", isExpanded: $isGrazingExpanded) {
            if pastureTasks.isEmpty {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.secondary)
                    Text("No tasks for this pasture")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(pastureTasks, id: \.id) { task in
                    PastureTaskRowView(task: task)
                    if task != pastureTasks.last {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Logs Section

    private var sortedLogs: [PastureLog] {
        let logs = pasture.logs?.allObjects as? [PastureLog] ?? []
        return logs.filter { $0.deletedAt == nil }
            .sorted { ($0.logDate ?? Date.distantPast) > ($1.logDate ?? Date.distantPast) }
    }

    private var logsSection: some View {
        InfoCard(title: "Activity Logs (\(sortedLogs.count))", isExpanded: $isNotesExpanded) {
            if sortedLogs.isEmpty {
                HStack {
                    Image(systemName: "list.bullet.clipboard")
                        .foregroundColor(.secondary)
                    Text("No activity logs")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(sortedLogs.prefix(5), id: \.id) { log in
                    PastureLogRowView(log: log)
                    if log != sortedLogs.prefix(5).last {
                        Divider()
                    }
                }
                if sortedLogs.count > 5 {
                    Text("Showing 5 of \(sortedLogs.count) logs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Map Section

    private var hasValidMapData: Bool {
        // Only show map if we have center coordinates AND boundary data
        return pasture.centerLat != 0 &&
               pasture.centerLng != 0 &&
               pasture.boundaryCoordinates != nil &&
               !(pasture.boundaryCoordinates?.isEmpty ?? true)
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let region = region {
                PastureMapView(
                    region: region,
                    boundaryPolygon: boundaryPolygon,
                    foragePolygon: foragePolygon,
                    pastureName: pasture.name ?? "Unknown"
                )
                .frame(height: 300)
                .cornerRadius(12)
            } else {
                // Fallback UI when map data exists but can't be displayed
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Map data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private var simpleMapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                Text("Center point only")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if pasture.centerLat != 0 && pasture.centerLng != 0 {
                    Text(String(format: "%.6f, %.6f", pasture.centerLat, pasture.centerLng))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    // MARK: - Helper Functions

    private func setupMapRegion() {
        guard pasture.centerLat != 0 && pasture.centerLng != 0 else {
            return
        }

        // Parse boundary polygon if available
        if let boundaryJSON = pasture.boundaryCoordinates {
            boundaryPolygon = parseGeoJSONPolygon(boundaryJSON)
        }

        // Parse forage polygon if available
        if let forageJSON = pasture.forageBoundaryCoordinates {
            foragePolygon = parseGeoJSONPolygon(forageJSON)
        }

        // Set region based on boundary or center point
        if let polygon = boundaryPolygon {
            let mapRect = polygon.boundingMapRect
            let padding = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
            region = MKCoordinateRegion(mapRect.insetBy(dx: -Double(padding.left), dy: -Double(padding.top)))
        } else {
            let center = CLLocationCoordinate2D(latitude: pasture.centerLat, longitude: pasture.centerLng)
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            region = MKCoordinateRegion(center: center, span: span)
        }
    }

    private func parseGeoJSONPolygon(_ jsonString: String) -> MKPolygon? {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = json["type"] as? String,
              type == "Polygon",
              let coordinates = json["coordinates"] as? [[[Double]]] else {
            return nil
        }

        // GeoJSON uses [longitude, latitude], MapKit uses CLLocationCoordinate2D(latitude, longitude)
        let outerRing = coordinates.first?.compactMap { coord -> CLLocationCoordinate2D? in
            guard coord.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        } ?? []

        guard !outerRing.isEmpty else { return nil }

        return MKPolygon(coordinates: outerRing, count: outerRing.count)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var occupancyColor: Color {
        guard pasture.carryingCapacity > 0 else { return .blue }
        let percentage = Double(pastureAnimals.count) / Double(pasture.carryingCapacity)

        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
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

    private func formatFieldValue(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}

// MARK: - Quick Stat Card Component

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

// MARK: - Shared Components
// Note: InfoCard and InfoRow are now defined in SharedComponents.swift

// MARK: - Task Row Component

struct PastureTaskRowView: View {
    @ObservedObject var task: Task

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled Task")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let description = task.taskDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        Label(formatDate(dueDate), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(task.priority?.capitalized ?? "Medium")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.2))
                        .foregroundColor(priorityColor)
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch task.status?.lowercased() {
        case "completed":
            return "checkmark.circle.fill"
        case "in_progress":
            return "circle.lefthalf.filled"
        default:
            return "circle"
        }
    }

    private var statusColor: Color {
        switch task.status?.lowercased() {
        case "completed":
            return .green
        case "in_progress":
            return .blue
        default:
            return .gray
        }
    }

    private var priorityColor: Color {
        switch task.priority?.lowercased() {
        case "high":
            return .red
        case "medium":
            return .orange
        case "low":
            return .green
        default:
            return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Log Row Component

struct PastureLogRowView: View {
    @ObservedObject var log: PastureLog

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Log type icon
            Image(systemName: logTypeIcon)
                .font(.caption)
                .foregroundColor(logTypeColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(log.title ?? "Untitled Log")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let description = log.logDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let logDate = log.logDate {
                        Label(formatDate(logDate), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(log.logType?.replacingOccurrences(of: "_", with: " ").capitalized ?? "General")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(logTypeColor.opacity(0.2))
                        .foregroundColor(logTypeColor)
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var logTypeIcon: String {
        switch log.logType?.lowercased() {
        case "soil_test":
            return "leaf.circle"
        case "maintenance":
            return "wrench.and.screwdriver"
        case "grazing":
            return "figure.walk"
        case "hay_cutting":
            return "scissors"
        default:
            return "doc.text"
        }
    }

    private var logTypeColor: Color {
        switch log.logType?.lowercased() {
        case "soil_test":
            return .brown
        case "maintenance":
            return .orange
        case "grazing":
            return .green
        case "hay_cutting":
            return .yellow
        default:
            return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatFieldValue(_ value: String) -> String {
        // Replace underscores with spaces and capitalize each word
        return value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}

#Preview {
    NavigationView {
        PastureDetailView(pasture: {
            let context = PersistenceController.preview.container.viewContext
            let pasture = Pasture(context: context)
            pasture.name = "North Field"
            pasture.pastureType = "Grazing"
            pasture.acreage = 25.5
            pasture.carryingCapacity = 30
            pasture.currentOccupancy = 22
            pasture.pastureCondition = "Good"
            pasture.isActive = true
            return pasture
        }())
    }
}
