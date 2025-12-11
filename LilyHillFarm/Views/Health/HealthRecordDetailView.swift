//
//  HealthRecordDetailView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct HealthRecordDetailView: View {
    @ObservedObject var record: HealthRecord
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingMarkComplete = false
    @State private var showingEdit = false

    var typeIcon: String {
        guard let type = HealthRecordType(rawValue: record.recordType ?? "") else {
            return "heart.text.square"
        }

        switch type {
        case .illness: return "cross.case"
        case .treatment: return "pills"
        case .vaccination: return "syringe"
        case .checkup: return "stethoscope"
        case .injury: return "bandage"
        case .surgery: return "bandage.fill"
        case .dental: return "mouth"
        case .other: return "heart.text.square"
        }
    }

    var typeColor: Color {
        guard let type = HealthRecordType(rawValue: record.recordType ?? "") else {
            return .gray
        }

        switch type {
        case .illness: return .red
        case .treatment: return .blue
        case .vaccination: return .green
        case .checkup: return .purple
        case .injury: return .orange
        case .surgery: return .red
        case .dental: return .cyan
        case .other: return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with icon
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(typeColor.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: typeIcon)
                            .font(.system(size: 36))
                            .foregroundColor(typeColor)
                    }

                    Text(record.displayType)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(record.displayDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Follow-up Alert
                if record.followUpCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Follow-up Completed")
                                .fontWeight(.semibold)
                            if let followUpDate = record.followUpDate {
                                Text("Was due: \(formatDate(followUpDate))")
                                    .font(.caption)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else if record.isFollowUpOverdue {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Follow-up Overdue")
                                .fontWeight(.semibold)
                            if let followUpDate = record.followUpDate {
                                Text("Due: \(formatDate(followUpDate))")
                                    .font(.caption)
                            }
                        }
                        Spacer()
                        Button("Mark Complete") {
                            showingMarkComplete = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else if record.isFollowUpNeeded {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Follow-up Scheduled")
                                .fontWeight(.semibold)
                            if let followUpDate = record.followUpDate, let days = record.daysUntilFollowUp {
                                Text("In \(days) day\(days == 1 ? "" : "s") - \(formatDate(followUpDate))")
                                    .font(.caption)
                            }
                        }
                        Spacer()
                        Button("Mark Complete") {
                            showingMarkComplete = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // Cattle Info
                if let cattle = record.cattle {
                    InfoCard(title: "Cattle") {
                        NavigationLink(destination: CattleDetailView(cattle: cattle)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(cattle.displayName)
                                        .font(.headline)
                                    Text(cattle.tagNumber ?? "No Tag")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Treatment Plan
                if let treatmentPlanId = record.treatmentPlanId, let recordId = record.id, let recordDate = record.date {
                    TreatmentPlanCard(
                        treatmentPlanId: treatmentPlanId,
                        healthRecordId: recordId,
                        healthRecordDate: recordDate,
                        viewContext: viewContext
                    )
                    .onAppear {
                        print("🔍 TreatmentPlanCard appeared for plan ID: \(treatmentPlanId)")
                    }
                }
                // Note: Health records without treatment plans are valid - no warning needed

                // Condition & Diagnosis
                if let condition = record.condition, !condition.isEmpty {
                    InfoCard(title: "Condition") {
                        Text(condition)
                            .font(.body)
                    }
                }

                // Treatment
                if record.treatment != nil || record.medication != nil {
                    InfoCard(title: "Treatment") {
                        if let treatment = record.treatment, !treatment.isEmpty {
                            InfoRow(label: "Treatment", value: treatment)
                        }

                        if let medication = record.medication, !medication.isEmpty {
                            InfoRow(label: "Medication", value: medication)
                        }

                        if let dosage = record.dosage, !dosage.isEmpty {
                            InfoRow(label: "Dosage", value: dosage)
                        }

                        if let method = record.administrationMethod, !method.isEmpty {
                            InfoRow(label: "Method", value: method)
                        }

                        if let vet = record.veterinarian, !vet.isEmpty {
                            InfoRow(label: "Veterinarian", value: vet)
                        }
                    }
                }

                // Measurements
                if (record.temperature as? Decimal ?? 0) > 0 || (record.weight as? Decimal ?? 0) > 0 || (record.cost as? Decimal ?? 0) > 0 {
                    InfoCard(title: "Measurements & Cost") {
                        if let temp = record.temperature as? Decimal, temp > 0 {
                            HStack {
                                Text("Temperature")
                                    .foregroundColor(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("\(temp as NSNumber) °F")
                                        .fontWeight(.medium)

                                    if !CattleValidation.isValidTemperature(temp) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                }
                            }
                        }

                        if let weight = record.weight as? Decimal, weight > 0 {
                            InfoRow(label: "Weight", value: "\(weight as NSNumber) lbs")
                        }

                        if let cost = record.cost as? Decimal, cost > 0 {
                            InfoRow(label: "Cost", value: "$\(cost as NSNumber)")
                        }
                    }
                }

                // Notes
                if let notes = record.notes, !notes.isEmpty {
                    InfoCard(title: "Notes") {
                        Text(notes)
                            .font(.body)
                    }
                }

                // Photos
                if !record.sortedPhotos.isEmpty {
                    InfoCard(title: "Photos (\(record.sortedPhotos.count))") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(record.sortedPhotos, id: \.objectID) { photo in
                                    if let thumbnailImage = photo.thumbnailImage {
                                        #if os(iOS)
                                        Image(uiImage: thumbnailImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(photo.isPrimary ? Color.blue : Color.clear, lineWidth: 3)
                                            )
                                        #else
                                        Image(nsImage: thumbnailImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(photo.isPrimary ? Color.blue : Color.clear, lineWidth: 3)
                                            )
                                        #endif
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Metadata
                InfoCard(title: "Record Information") {
                    if let createdAt = record.createdAt {
                        InfoRow(label: "Created", value: formatDateTime(createdAt))
                    }

                    InfoRow(label: "Days Since", value: "\(record.daysSinceRecord)")
                }
            }
            .padding()
        }
        .navigationTitle("Health Record")
    #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
    #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditHealthRecordView(healthRecord: record)
        }
        .confirmationDialog("Mark Follow-up Complete", isPresented: $showingMarkComplete) {
            Button("Mark as Complete") {
                markFollowUpComplete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark this follow-up appointment as completed?")
        }
    }

    // MARK: - Actions

    private func markFollowUpComplete() {
        record.followUpCompleted = true
        try? viewContext.save()
    }

    // MARK: - Formatters

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
}

// MARK: - Treatment Plan Card

struct TreatmentPlanCard: View {
    let treatmentPlanId: UUID
    let healthRecordId: UUID
    let healthRecordDate: Date
    let viewContext: NSManagedObjectContext
    @State private var treatmentPlan: TreatmentPlan?
    @State private var treatmentSteps: [TreatmentPlanStep] = []
    @State private var existingTasks: [Task] = []
    @State private var showingCreateTasks = false
    @State private var hasLoaded = false
    @State private var viewAppearCount = 0

    var body: some View {
        Group {
            if let plan = treatmentPlan {
                InfoCard(title: "Treatment Plan") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Plan header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.name ?? "Unknown Plan")
                                .font(.headline)

                            if let condition = plan.condition, !condition.isEmpty {
                                HStack {
                                    Image(systemName: "heart.text.square")
                                        .foregroundColor(.blue)
                                    Text(condition)
                                        .foregroundColor(.blue)
                                }
                                .font(.subheadline)
                            }

                            if let description = plan.planDescription, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                        }

                        // Treatment steps
                        if !treatmentSteps.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            Text("Treatment Steps")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            ForEach(treatmentSteps, id: \.objectID) { step in
                                TreatmentStepRow(
                                    step: step,
                                    recordDate: healthRecordDate,
                                    task: taskForStep(step),
                                    viewContext: viewContext
                                )
                            }

                            // Create tasks button
                            if hasUnscheduledSteps {
                                Button(action: { showingCreateTasks = true }) {
                                    HStack {
                                        Image(systemName: "calendar.badge.plus")
                                        Text("Create Tasks for Steps")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            } else {
                // Show loading or error state
                InfoCard(title: "Treatment Plan") {
                    if hasLoaded {
                        Text("Failed to load treatment plan")
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading treatment plan...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .task {
            if !hasLoaded {
                print("⚡️ TreatmentPlanCard task - calling loadTreatmentPlan()")
                loadTreatmentPlan()
                hasLoaded = true
                print("⚡️ After loadTreatmentPlan, treatmentPlan is: \(treatmentPlan?.name ?? "nil")")
            }
        }
        .onAppear {
            viewAppearCount += 1
            // Reload tasks on subsequent appearances to pick up status changes from task management
            if viewAppearCount > 1 {
                print("🔄 TreatmentPlanCard reappeared, reloading tasks...")
                reloadTasks()
            }
        }
        .confirmationDialog("Create Treatment Tasks", isPresented: $showingCreateTasks) {
                Button("Create All Tasks") {
                    createTasksForAllSteps()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Create tasks for all treatment steps that don't have tasks yet?")
            }
    }

    private var hasUnscheduledSteps: Bool {
        treatmentSteps.contains { step in
            taskForStep(step) == nil
        }
    }

    private func loadTreatmentPlan() {
        print("🔍 Loading treatment plan with ID: \(treatmentPlanId)")

        // First check if we can access via relationship
        let healthRecordFetch: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
        healthRecordFetch.predicate = NSPredicate(format: "id == %@", healthRecordId as CVarArg)

        if let healthRecord = try? viewContext.fetch(healthRecordFetch).first,
           let planFromRelationship = healthRecord.treatmentPlan {
            print("📋 Found treatment plan via relationship: \(planFromRelationship.name ?? "Unknown")")
            treatmentPlan = planFromRelationship
        } else {
            // Fallback to fetch by ID
            let planFetchRequest: NSFetchRequest<TreatmentPlan> = TreatmentPlan.fetchRequest()
            planFetchRequest.predicate = NSPredicate(format: "id == %@", treatmentPlanId as CVarArg)

            do {
                let planResults = try viewContext.fetch(planFetchRequest)
                treatmentPlan = planResults.first
                print("📋 Found treatment plan by ID fetch: \(treatmentPlan?.name ?? "nil")")
            } catch {
                print("❌ Failed to fetch treatment plan: \(error)")
            }
        }

        guard treatmentPlan != nil else {
            print("❌ No treatment plan found!")
            return
        }

        // Load steps
        let stepsFetchRequest: NSFetchRequest<TreatmentPlanStep> = TreatmentPlanStep.fetchRequest()
        stepsFetchRequest.predicate = NSPredicate(format: "treatmentPlan.id == %@", treatmentPlanId as CVarArg)
        stepsFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TreatmentPlanStep.stepNumber, ascending: true)]

        let tasksFetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        tasksFetchRequest.predicate = NSPredicate(format: "healthRecord.id == %@", healthRecordId as CVarArg)

        do {
            treatmentSteps = try viewContext.fetch(stepsFetchRequest)
            print("📋 Found \(treatmentSteps.count) treatment steps")

            existingTasks = try viewContext.fetch(tasksFetchRequest)
            print("📋 Found \(existingTasks.count) existing tasks for health record")
        } catch {
            print("❌ Failed to fetch treatment steps/tasks: \(error)")
        }
    }

    private func reloadTasks() {
        // Reload just the tasks to pick up status changes
        let tasksFetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        tasksFetchRequest.predicate = NSPredicate(format: "healthRecord.id == %@", healthRecordId as CVarArg)

        do {
            existingTasks = try viewContext.fetch(tasksFetchRequest)
            print("🔄 Reloaded \(existingTasks.count) tasks for health record")
        } catch {
            print("❌ Failed to reload tasks: \(error)")
        }
    }

    private func taskForStep(_ step: TreatmentPlanStep) -> Task? {
        guard let stepDueDate = calculateDueDate(for: step) else { return nil }

        // Find task matching this step's due date
        return existingTasks.first { task in
            guard let taskDueDate = task.dueDate else { return false }
            let calendar = Calendar.current
            return calendar.isDate(taskDueDate, inSameDayAs: stepDueDate)
        }
    }

    private func calculateDueDate(for step: TreatmentPlanStep) -> Date? {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: Int(step.dayNumber), to: healthRecordDate)
    }

    private func createTasksForAllSteps() {
        let healthRecordFetch: NSFetchRequest<HealthRecord> = HealthRecord.fetchRequest()
        healthRecordFetch.predicate = NSPredicate(format: "id == %@", healthRecordId as CVarArg)

        guard let healthRecord = try? viewContext.fetch(healthRecordFetch).first else {
            print("Failed to find health record")
            return
        }

        for step in treatmentSteps {
            // Skip if task already exists for this step
            if taskForStep(step) != nil {
                continue
            }

            guard let dueDate = calculateDueDate(for: step) else { continue }

            let task = Task(context: viewContext)
            task.id = UUID()
            task.title = step.title ?? "Treatment Step \(step.stepNumber)"
            task.taskDescription = step.stepDescription
            task.taskType = "health_followup"
            task.priority = "medium"
            task.status = "pending"
            task.dueDate = dueDate
            task.healthRecord = healthRecord
            task.cattle = healthRecord.cattle
            task.createdAt = Date()
            task.updatedAt = Date()

            // Add notes with medication and dosage info
            var notes = ""
            if let medication = step.medication, !medication.isEmpty {
                notes += "Medication: \(medication)"
            }
            if let dosage = step.dosage, !dosage.isEmpty {
                if !notes.isEmpty { notes += "\n" }
                notes += "Dosage: \(dosage)"
            }
            if let method = step.administrationMethod, !method.isEmpty {
                if !notes.isEmpty { notes += "\n" }
                notes += "Method: \(method)"
            }
            if let stepNotes = step.notes, !stepNotes.isEmpty {
                if !notes.isEmpty { notes += "\n" }
                notes += stepNotes
            }
            if !notes.isEmpty {
                task.notes = notes
            }
        }

        do {
            try viewContext.save()
            // Reload to show new tasks
            loadTreatmentPlan()
        } catch {
            print("Failed to create tasks: \(error)")
        }
    }
}

// MARK: - Treatment Step Row

struct TreatmentStepRow: View {
    @ObservedObject var step: TreatmentPlanStep
    let recordDate: Date
    let task: Task?
    let viewContext: NSManagedObjectContext
    @State private var showingMarkComplete = false

    private var dueDate: Date? {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: Int(step.dayNumber), to: recordDate)
    }

    private var statusColor: Color {
        guard let task = task else { return .gray }

        if task.status == "completed" {
            return .green
        } else if task.status == "in_progress" {
            return .blue
        } else {
            return .orange
        }
    }

    private var statusIcon: String {
        guard let task = task else { return "circle" }

        if task.status == "completed" {
            return "checkmark.circle.fill"
        } else if task.status == "in_progress" {
            return "arrow.forward.circle.fill"
        } else {
            return "clock.circle.fill"
        }
    }

    private var statusText: String {
        guard let task = task else { return "Not Scheduled" }

        if task.status == "completed" {
            return "Completed"
        } else if task.status == "in_progress" {
            return "In Progress"
        } else {
            return "Pending"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Step number badge
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Text("\(step.stepNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Title and status
                    HStack {
                        Text(step.title ?? "Step \(step.stepNumber)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: statusIcon)
                                .font(.caption)
                            Text(statusText)
                                .font(.caption)
                        }
                        .foregroundColor(statusColor)
                    }

                    // Due date
                    if let dueDate = dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text("Day \(step.dayNumber): \(formatDate(dueDate))")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Description
                    if let description = step.stepDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }

                    // Medication info
                    if let medication = step.medication, !medication.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "pills.fill")
                                .font(.caption2)
                            Text(medication)
                                .font(.caption)
                            if let dosage = step.dosage, !dosage.isEmpty {
                                Text("- \(dosage)")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)
                    }

                    // Mark complete button
                    if let task = task, task.status != "completed" {
                        Button(action: { showingMarkComplete = true }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Mark Complete")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(6)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .confirmationDialog("Mark Step Complete", isPresented: $showingMarkComplete) {
            Button("Mark as Complete") {
                markStepComplete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark this treatment step as completed?")
        }
    }

    private func markStepComplete() {
        guard let task = task else { return }

        task.status = "completed"
        task.completedAt = Date()
        task.updatedAt = Date()

        do {
            try viewContext.save()
            print("✅ Marked step complete in Core Data")

            // Immediately sync to Supabase
            _Concurrency.Task {
                do {
                    let repository = TaskRepository(context: viewContext)
                    try await repository.pushToSupabase(task)
                    print("✅ Task completion synced to Supabase")
                } catch {
                    print("❌ Failed to sync task completion to Supabase: \(error)")
                }
            }
        } catch {
            print("❌ Failed to mark step complete: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        HealthRecordDetailView(record: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            cattle.tagNumber = "LHF-001"
            cattle.name = "Test Cow"
            let record = HealthRecord.create(for: cattle, type: .vaccination, in: context)
            record.condition = "Annual vaccination"
            record.treatment = "Modified live vaccine"
            record.medication = "Bovishield Gold 5"
            record.veterinarian = "Dr. Smith"
            record.notes = "Annual vaccination administered. No adverse reactions observed."
            return record
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
