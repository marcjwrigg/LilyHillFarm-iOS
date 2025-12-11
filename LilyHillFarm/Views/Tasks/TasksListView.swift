//
//  TasksListView.swift
//  LilyHillFarm
//
//  Main view for displaying and managing tasks
//

import SwiftUI

struct TasksListView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var showingAddTask = false
    @State private var selectedFilter: TaskFilter = .open

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(TaskFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Task List
                if viewModel.isLoading {
                    ProgressView("Loading tasks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredTasks(for: selectedFilter).isEmpty {
                    emptyState
                } else {
                    tasksList
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Subviews

    private var tasksList: some View {
        List {
            ForEach(viewModel.filteredTasks(for: selectedFilter)) { task in
                TaskRowView(task: task, viewModel: viewModel)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await viewModel.loadTasks()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No \(selectedFilter.rawValue.lowercased()) tasks")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to create a new task")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: TaskItem
    @ObservedObject var viewModel: TasksViewModel

    var body: some View {
        NavigationLink(destination: TaskDetailView(viewModel: viewModel, task: task)) {
            HStack(spacing: 12) {
                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    HStack(spacing: 12) {
                        // Priority badge
                        priorityBadge(task.priority)

                        // Due date
                        if let dueDate = task.dueDate {
                            Label(formatDate(dueDate), systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                        }

                        // Cattle tag if linked
                        if let cattleTag = task.cattleTag {
                            Label(cattleTag, systemImage: "tag")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Completion checkbox button (prominent on right)
                Button(action: {
                    toggleComplete()
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(task.isCompleted ? .green : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteTask()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleComplete() {
        _Concurrency.Task {
            await viewModel.toggleTaskCompletion(task)
        }
    }

    private func deleteTask() {
        _Concurrency.Task {
            await viewModel.deleteTask(task)
        }
    }

    private func priorityBadge(_ priority: String) -> some View {
        Text(priority.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor(priority).opacity(0.2))
            .foregroundColor(priorityColor(priority))
            .cornerRadius(4)
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "urgent": return .red
        case "high": return .orange
        case "medium": return .blue
        case "low": return .gray
        default: return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !task.isCompleted
    }
}

// MARK: - Filter Enum

enum TaskFilter: String, CaseIterable, Identifiable {
    case open = "Open"
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"

    var id: String { rawValue }
}

// MARK: - Preview

struct TasksListView_Previews: PreviewProvider {
    static var previews: some View {
        TasksListView()
    }
}
