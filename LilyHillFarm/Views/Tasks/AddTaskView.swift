//
//  AddTaskView.swift
//  LilyHillFarm
//
//  View for creating a new task
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TasksViewModel

    @State private var title = ""
    @State private var description = ""
    @State private var taskType: TaskType = .general
    @State private var priority: TaskPriority = .medium
    @State private var dueDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var hasDueDate = true
    @State private var selectedCattle: Cattle?
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
                    // TODO: Add cattle picker when Core Data is set up
                    Text("Select cattle...")
                        .foregroundColor(.secondary)
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
        }
    }

    private func createTask() {
        _Concurrency.Task {
            let newTask = TaskItem(
                id: UUID(),
                title: title,
                description: description.isEmpty ? nil : description,
                taskType: taskType.rawValue,
                priority: priority.rawValue,
                status: "pending",
                dueDate: hasDueDate ? dueDate : nil,
                createdAt: Date()
            )

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
    case general
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healthFollowup: return "Health Follow-up"
        case .breeding: return "Breeding"
        case .feeding: return "Feeding"
        case .maintenance: return "Maintenance"
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
