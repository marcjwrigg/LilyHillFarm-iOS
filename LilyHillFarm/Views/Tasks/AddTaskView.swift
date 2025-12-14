//
//  AddTaskView.swift
//  LilyHillFarm
//
//  View for creating a new task
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: TasksViewModel

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil AND currentStatus == %@", "Active"),
        animation: .default)
    private var cattle: FetchedResults<Cattle>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pasture.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES AND deletedAt == nil"),
        animation: .default)
    private var pastures: FetchedResults<Pasture>

    @State private var title = ""
    @State private var description = ""
    @State private var taskType: TaskType = .general
    @State private var priority: TaskPriority = .medium
    @State private var dueDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var hasDueDate = true
    @State private var selectedCattle: Set<Cattle> = []
    @State private var showCattlePicker = false
    @State private var selectedPastures: Set<Pasture> = []
    @State private var showPasturePicker = false
    @State private var notes = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Classification") {
                    Picker("Type", selection: $taskType) {
                        ForEach(TaskType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.rawValue.capitalized)
                                .tag(priority)
                        }
                    }
                }

                Section("Schedule") {
                    Toggle("Set due date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Link to Cattle (Optional)") {
                    MultiSelectDisplay(
                        selectedItems: selectedCattle,
                        itemLabel: { $0.displayName },
                        placeholder: "Select cattle",
                        onTap: { showCattlePicker = true }
                    )
                }

                Section("Link to Pastures (Optional)") {
                    MultiSelectDisplay(
                        selectedItems: selectedPastures,
                        itemLabel: { $0.displayValue },
                        placeholder: "Select pastures",
                        onTap: { showPasturePicker = true }
                    )
                }

                Section("Additional Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showCattlePicker) {
                MultiSelectPicker(
                    title: "Select Cattle",
                    items: Array(cattle),
                    selectedItems: $selectedCattle,
                    itemLabel: { $0.displayName },
                    itemSubtitle: { $0.tagNumber ?? "No Tag" }
                )
            }
            .sheet(isPresented: $showPasturePicker) {
                MultiSelectPicker(
                    title: "Select Pastures",
                    items: Array(pastures),
                    selectedItems: $selectedPastures,
                    itemLabel: { $0.displayValue }
                )
            }
        }
    }

    private func createTask() {
        _Concurrency.Task {
            // Create task with cattle and pasture IDs
            var newTask = TaskItem(
                id: UUID(),
                title: title,
                description: description.isEmpty ? nil : description,
                taskType: taskType.rawValue,
                priority: priority.rawValue,
                status: "pending",
                dueDate: hasDueDate ? dueDate : nil,
                createdAt: Date()
            )

            // Add cattle IDs and pasture IDs to notes for now
            // TODO: Update TaskItem or save directly to Core Data Task entity with cattleIds and pastureIds arrays
            var additionalInfo = ""
            if !selectedCattle.isEmpty {
                let cattleList = selectedCattle.map { $0.displayName }.joined(separator: ", ")
                additionalInfo += "Cattle: \(cattleList)\n"
            }
            if !selectedPastures.isEmpty {
                let pastureList = selectedPastures.map { $0.displayValue }.joined(separator: ", ")
                additionalInfo += "Pastures: \(pastureList)\n"
            }
            if !additionalInfo.isEmpty {
                newTask.description = (newTask.description ?? "") + "\n\n" + additionalInfo
            }
            if !notes.isEmpty {
                newTask.description = (newTask.description ?? "") + "\n\n" + notes
            }

            await viewModel.createTask(newTask)
            dismiss()
        }
    }
}

// MARK: - Task Type Enum

enum TaskType: String, CaseIterable, Identifiable {
    case healthFollowup = "health_followup"
    case breeding
    case feeding
    case maintenance
    case pasture
    case herdManagement = "herd_management"
    case general
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healthFollowup: return "Health Follow-up"
        case .breeding: return "Breeding"
        case .feeding: return "Feeding"
        case .maintenance: return "Maintenance"
        case .pasture: return "Pasture"
        case .herdManagement: return "Herd Management"
        case .general: return "General"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .healthFollowup: return "heart.text.square"
        case .breeding: return "heart.fill"
        case .feeding: return "leaf.fill"
        case .maintenance: return "wrench.fill"
        case .pasture: return "map"
        case .herdManagement: return "chart.bar.doc.horizontal"
        case .general: return "checklist"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Priority Enum

enum TaskPriority: String, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }
}

// MARK: - Preview

struct AddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskView(viewModel: TasksViewModel())
    }
}
