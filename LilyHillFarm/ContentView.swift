//
//  ContentView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var autoSync: AutoSyncService
    @State private var selectedTab: Int = 0

    init() {
        let context = PersistenceController.shared.container.viewContext
        _autoSync = StateObject(wrappedValue: AutoSyncService(context: context))
    }

    var body: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar")
            }
            .tag(0)

            NavigationStack {
                CattleListView()
            }
            .tabItem {
                Label("Herd", systemImage: "pawprint")
            }
            .tag(1)

            // Marc AI Chat
            ChatView(
                aiService: AIService(supabaseManager: SupabaseManager.shared),
                supabaseManager: SupabaseManager.shared
            )
            .tabItem {
                Image("marc-tab-icon")
                    .renderingMode(.original)
            }
            .tag(2)

            NavigationStack {
                HealthDashboardView()
            }
            .tabItem {
                Label("Health", systemImage: "heart.text.square")
            }
            .tag(3)

            NavigationStack {
                MoreView()
            }
            .tabItem {
                Label("More", systemImage: "ellipsis.circle")
            }
            .tag(4)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToDashboard"))) { _ in
            selectedTab = 0
        }
        .environment(\.managedObjectContext, viewContext)
        #elseif os(macOS)
        MacOSContentView()
        #endif
    }
}

// MARK: - macOS Content View

#if os(macOS)
struct MacOSContentView: View {
    @State private var selectedSection: SidebarSection? = .dashboard
    @State private var selectedCattle: Cattle?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    enum SidebarSection: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case herd = "Herd"
        case breeding = "Breeding"
        case health = "Health"
        case more = "More"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar"
            case .herd: return "pawprint"
            case .breeding: return "heart.circle"
            case .health: return "heart.text.square"
            case .more: return "ellipsis.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar (Column 1)
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: section.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } content: {
            // Content (Column 2) - List/Index views
            Group {
                switch selectedSection {
                case .dashboard:
                    DashboardView()
                case .herd:
                    MacOSCattleListView(selectedCattle: $selectedCattle)
                case .breeding:
                    BreedingDashboardView()
                case .health:
                    HealthDashboardView()
                case .more:
                    MoreView()
                case .none:
                    Text("Select a section")
                        .foregroundColor(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
        } detail: {
            // Detail (Column 3) - Detail views
            if let cattle = selectedCattle {
                CattleDetailView(cattle: cattle)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "pawprint")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select an animal to view details")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
#endif

// MARK: - Dashboard View

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var tasksViewModel = TasksViewModel()
    @State private var showingAddTask = false
    @State private var showingAddHealthRecord = false
    @State private var showingAnimalPicker = false
    @State private var selectedCattleForHealth: Cattle?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        animation: .default)
    private var cattle: FetchedResults<Cattle>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PregnancyRecord.expectedCalvingDate, ascending: true)],
        predicate: NSPredicate(format: "status == %@ OR status == %@ OR status == %@", "bred", "confirmed", "exposed"),
        animation: .default)
    private var activePregnancies: FetchedResults<PregnancyRecord>

    var activeCattle: [Cattle] {
        cattle.filter { $0.currentStatus == CattleStatus.active.rawValue }
    }

    var overdueTasks: [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return tasksViewModel.tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < today && !task.isCompleted
        }
    }

    var next7DaysTasks: [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        return tasksViewModel.tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= today && dueDate <= weekFromNow && !task.isCompleted
        }
    }

    var urgentTasks: [TaskItem] {
        // Combine overdue and next 7 days, sort by due date (overdue first)
        let combined = overdueTasks + next7DaysTasks
        return combined.sorted { task1, task2 in
            guard let date1 = task1.dueDate, let date2 = task2.dueDate else { return false }
            return date1 < date2
        }
    }

    var calvesDueNext7Days: Int {
        let today = Date()
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today)!

        return activePregnancies.filter { pregnancy in
            guard let expectedDate = pregnancy.expectedCalvingDate else { return false }
            return expectedDate >= today && expectedDate <= weekFromNow
        }.count
    }

    var cattleByStage: [(stage: String, count: Int)] {
        var dict: [String: Int] = [:]
        for animal in activeCattle {
            let stageName = animal.currentStage ?? "Unknown"
            dict[stageName, default: 0] += 1
        }
        // Sort by count descending
        return dict.map { (stage: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    @ViewBuilder
    func destinationForTask(_ task: TaskItem) -> some View {
        if let cattleId = task.cattleId,
           let cattle = cattle.first(where: { $0.id == cattleId }) {
            CattleDetailView(cattle: cattle)
        } else {
            TaskDetailView(viewModel: tasksViewModel, task: task)
        }
    }

    // MARK: - View Sections

    private var dashboardHeader: some View {
        VStack(spacing: 4) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
        }
        .padding(.top)
    }

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            CompactStatCard(
                title: "Active Cattle",
                value: "\(activeCattle.count)",
                icon: "pawprint.fill",
                color: .blue
            )
            CompactStatCard(
                title: "Overdue Tasks",
                value: "\(overdueTasks.count)",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            CompactStatCard(
                title: "Calves Due (7d)",
                value: "\(calvesDueNext7Days)",
                icon: "calendar.badge.clock",
                color: .green
            )
        }
        .padding(.horizontal)
    }

    private var herdOverviewSection: some View {
        Group {
            if !activeCattle.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Herd Overview")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack(spacing: 8) {
                        ForEach(cattleByStage.prefix(5), id: \.stage) { item in
                            VStack(spacing: 4) {
                                Text("\(item.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(item.stage)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var urgentTasksSection: some View {
        Group {
            if !urgentTasks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tasks - Next 7 Days and Overdue")
                            .font(.headline)
                        Spacer()
                        NavigationLink(destination: TasksListView()) {
                            Text("View All")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 8) {
                        ForEach(urgentTasks.prefix(5), id: \.id) { task in
                            NavigationLink(destination: destinationForTask(task)) {
                                CompactTaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button(action: { showingAddTask = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Add Task")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: { showingAnimalPicker = true }) {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title3)
                        Text("Add Health")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dashboardHeader
                statsSection
                herdOverviewSection
                urgentTasksSection
                quickActionsSection
                Spacer(minLength: 20)
            }
            #if os(macOS)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
            }
        }
        .sheet(isPresented: $showingAddTask, onDismiss: {
            _Concurrency.Task {
                await tasksViewModel.loadTasks()
            }
        }) {
            NavigationStack {
                AddTaskView(viewModel: tasksViewModel)
            }
        }
        .sheet(isPresented: $showingAnimalPicker) {
            NavigationStack {
                AnimalPickerView(cattle: Array(activeCattle), selectedCattle: $selectedCattleForHealth)
                    .navigationTitle("Select Animal")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAnimalPicker = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingAddHealthRecord, onDismiss: {
            _Concurrency.Task {
                await tasksViewModel.loadTasks()
            }
        }) {
            NavigationStack {
                if let cattle = selectedCattleForHealth {
                    AddHealthRecordView(cattle: cattle) { _ in
                        selectedCattleForHealth = nil
                    }
                }
            }
        }
        .onChange(of: selectedCattleForHealth) { oldValue, newValue in
            if newValue != nil {
                showingAnimalPicker = false
                showingAddHealthRecord = true
            }
        }
        .task {
            await tasksViewModel.loadTasks()
        }
    }
}

// MARK: - Stat Card Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String?

    init(title: String, value: String, icon: String, color: Color, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CompactStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Compact Task Row

struct CompactTaskRow: View {
    let task: TaskItem

    var isOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate < Date()
    }

    var formattedDate: String {
        guard let dueDate = task.dueDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: dueDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "clock.fill")
                .foregroundColor(isOverdue ? .orange : .blue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let cattleTag = task.cattleTag {
                        Label(cattleTag, systemImage: "tag")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundColor(isOverdue ? .orange : .secondary)
                }
            }

            Spacer()

            Text(task.priority.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(priorityColor.opacity(0.15))
                .foregroundColor(priorityColor)
                .cornerRadius(4)
        }
        .padding(12)
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        .cornerRadius(8)
    }

    var priorityColor: Color {
        switch task.priority.lowercased() {
        case "urgent": return .red
        case "high": return .orange
        case "medium": return .blue
        case "low": return .gray
        default: return .gray
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
