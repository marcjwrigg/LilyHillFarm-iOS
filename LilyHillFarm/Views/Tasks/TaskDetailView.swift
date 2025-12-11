//
//  TaskDetailView.swift
//  LilyHillFarm
//
//  Detail view for a single task
//

import SwiftUI

struct TaskDetailView: View {
    @ObservedObject var viewModel: TasksViewModel
    let task: TaskItem

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Badge
                HStack {
                    Spacer()
                    statusBadge
                    Spacer()
                }
                .padding(.top)

                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(task.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Task Details
                VStack(spacing: 16) {
                    // Priority
                    DetailRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: priorityColor,
                        label: "Priority",
                        value: task.priority.capitalized
                    )

                    // Type
                    DetailRow(
                        icon: task.typeIcon,
                        iconColor: .blue,
                        label: "Type",
                        value: task.taskType.capitalized
                    )

                    // Due Date
                    if let dueDate = task.dueDate {
                        DetailRow(
                            icon: "calendar",
                            iconColor: isOverdue(dueDate) ? .red : .blue,
                            label: "Due Date",
                            value: formatDate(dueDate),
                            badge: dueDateBadge(dueDate)
                        )
                    }

                    // Linked Cattle
                    if let cattleTag = task.cattleTag {
                        DetailRow(
                            icon: "tag.fill",
                            iconColor: .green,
                            label: "Linked Animal",
                            value: cattleTag
                        )
                    }

                    // Completion Date
                    if let completedAt = task.completedAt {
                        DetailRow(
                            icon: "checkmark.circle.fill",
                            iconColor: .green,
                            label: "Completed",
                            value: formatDateTime(completedAt)
                        )
                    }
                }
                .padding(.horizontal)

                // Description
                if let description = task.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)

                        Text(description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Notes - removed from TaskItem (not in database)

                // Actions
                VStack(spacing: 12) {
                    // Toggle Completion
                    Button(action: { toggleComplete() }) {
                        HStack {
                            Image(systemName: task.isCompleted ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                            Text(task.isCompleted ? "Mark as Incomplete" : "Mark as Complete")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(task.isCompleted ? Color.orange : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    // Delete
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Task")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .padding(.bottom)
        }
        .navigationTitle("Task Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Delete Task", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("Are you sure you want to delete this task?")
        }
    }

    // MARK: - Subviews

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .orange)

            Text(task.status.capitalized.replacingOccurrences(of: "_", with: " "))
                .font(.headline)
                .foregroundColor(task.isCompleted ? .green : .orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(task.isCompleted ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(20)
    }

    private var priorityColor: Color {
        switch task.priority.lowercased() {
        case "urgent": return .red
        case "high": return .orange
        case "medium": return .blue
        case "low": return .gray
        default: return .gray
        }
    }

    // MARK: - Helper Functions

    private func toggleComplete() {
        _Concurrency.Task {
            await viewModel.toggleTaskCompletion(task)
        }
    }

    private func deleteTask() {
        _Concurrency.Task {
            await viewModel.deleteTask(task)
            dismiss()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !task.isCompleted
    }

    private func dueDateBadge(_ date: Date) -> String? {
        if task.isCompleted {
            return nil
        }

        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0

        if days < 0 {
            return "\(abs(days))d overdue"
        } else if days == 0 {
            return "Due today"
        } else if days <= 7 {
            return "\(days)d remaining"
        }

        return nil
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text(value)
                        .font(.body)
                        .fontWeight(.medium)

                    if let badge = badge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(iconColor.opacity(0.2))
                            .foregroundColor(iconColor)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        TaskDetailView(
            viewModel: TasksViewModel(),
            task: TaskItem(
                title: "Vaccinate Cattle",
                description: "Annual vaccination for the herd",
                taskType: "health",
                priority: "high",
                status: "pending",
                dueDate: Date(),
                cattleTag: "LHF-001"
            )
        )
    }
}
