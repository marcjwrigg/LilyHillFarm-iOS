//
//  AddHealthRecordView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData
import Supabase

// Simple struct to hold health condition data from Supabase
struct HealthConditionItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
}

struct AddHealthRecordView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Optional callback when record is saved successfully
    var onRecordSaved: ((HealthRecord) -> Void)?

    // Record details
    @State private var recordType: HealthRecordType = .checkup
    @State private var date = Date()
    @State private var selectedCondition: HealthConditionItem?
    @State private var treatment = ""
    @State private var medication = ""
    @State private var dosage = ""
    @State private var veterinarian = ""
    @State private var notes = ""

    // Cost
    @State private var recordCost = false
    @State private var cost = ""

    // Follow-up
    @State private var needsFollowUp = false
    @State private var followUpDate = Date()
    @State private var followUpCompleted = false

    // Health Conditions
    @State private var healthConditions: [HealthConditionItem] = []
    @State private var isLoadingConditions = false

    // Treatment Plan
    @State private var treatmentPlans: [TreatmentPlan] = []
    @State private var filteredTreatmentPlans: [TreatmentPlan] = []
    @State private var selectedTreatmentPlan: TreatmentPlan?
    @State private var isLoadingPlans = false
    @State private var treatmentPlanSteps: [TreatmentPlanStep] = []

    // Photos
    @State private var showingPhotoPicker = false
    @State private var showingPhotoSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    #if os(iOS)
    @State private var selectedImages: [UIImage] = []
    #else
    @State private var selectedImages: [NSImage] = []
    #endif

    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            basicInfoSection
            conditionSection
            treatmentPlanSection
            treatmentSection

            costSection
            followUpSection
            photoSection
            cattleInfoSection
        }
        .navigationTitle("Add Health Record")
    #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
    #endif
        .onAppear {
            loadHealthConditions()
            loadTreatmentPlans()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveRecord()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Add Photo", isPresented: $showingPhotoSourcePicker) {
            #if os(iOS)
            Button("Take Photo") {
                showingCamera = true
            }
            Button("Choose from Library") {
                showingPhotoLibrary = true
            }
            Button("Cancel", role: .cancel) {}
            #endif
        }
        .sheet(isPresented: $showingCamera) {
            #if os(iOS)
            ImagePickerController(sourceType: .camera) { image in
                selectedImages.append(image)
            }
            #endif
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            #if os(iOS)
            PhotosLibraryPicker(maxSelection: 10 - selectedImages.count) { images in
                selectedImages.append(contentsOf: images)
            }
            #endif
        }
        .sheet(isPresented: $showingPhotoPicker) {
            #if os(iOS)
            PhotoPickerView(maxSelection: 10) { images in
                selectedImages.append(contentsOf: images)
            }
            #else
            PhotoPickerView(maxSelection: 10) { images in
                selectedImages.append(contentsOf: images)
            }
            #endif
        }
    }

    // MARK: - View Components

    private var basicInfoSection: some View {
        Section("Record Information") {
            Picker("Type *", selection: $recordType) {
                ForEach(HealthRecordType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
        }
    }

    private var conditionSection: some View {
        Section("Condition") {
            if isLoadingConditions {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading conditions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Picker("Condition *", selection: $selectedCondition) {
                    Text("Select Condition").tag(nil as HealthConditionItem?)
                    ForEach(healthConditions) { condition in
                        Text(condition.name).tag(condition as HealthConditionItem?)
                    }
                }
                .onChange(of: selectedCondition) {
                    filterTreatmentPlans()
                    selectedTreatmentPlan = nil

                    // Auto-populate notes with condition description
                    if let condition = selectedCondition, let description = condition.description, !description.isEmpty {
                        if notes.isEmpty {
                            notes = description
                            print("📝 Auto-populated notes from condition: \(description)")
                        }
                    }
                }
            }

            TextEditor(text: $notes)
                .frame(minHeight: 60)
        }
    }

    private var treatmentPlanSection: some View {
        Section("Treatment Plan") {
            if isLoadingPlans {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading treatment plans...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if selectedCondition == nil {
                Text("Select a condition first to see available treatment plans")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                Picker("Treatment Plan", selection: $selectedTreatmentPlan) {
                    Text("None").tag(nil as TreatmentPlan?)
                    ForEach(filteredTreatmentPlans, id: \.id) { plan in
                        Text(plan.name ?? "Unknown").tag(plan as TreatmentPlan?)
                    }
                }
                .onChange(of: selectedTreatmentPlan) {
                    // Auto-populate treatment details from first step
                    if let plan = selectedTreatmentPlan {
                        populateTreatmentDetails(from: plan)
                    } else {
                        // Clear steps if no plan selected
                        treatmentPlanSteps = []
                    }
                }

                if let selected = selectedTreatmentPlan {
                    VStack(alignment: .leading, spacing: 8) {
                        if let description = selected.planDescription, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Display treatment plan steps
                        if !treatmentPlanSteps.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            Text("Treatment Steps (\(treatmentPlanSteps.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            ForEach(treatmentPlanSteps, id: \.objectID) { step in
                                TreatmentStepPreview(step: step, recordDate: date)
                            }
                        }
                    }
                }
            }
        }
    }

    private var treatmentSection: some View {
        Section("Treatment") {
            TextField("Treatment", text: $treatment)
            TextField("Medication", text: $medication)
            TextField("Dosage", text: $dosage)
            TextField("Veterinarian", text: $veterinarian)
        }
    }

    private var costSection: some View {
        Section("Cost") {
            Toggle("Record Cost", isOn: $recordCost)
            if recordCost {
                HStack {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("Cost", text: $cost)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }
        }
    }

    private var followUpSection: some View {
        Section("Follow-up") {
            Toggle("Needs Follow-up", isOn: $needsFollowUp)

            if needsFollowUp {
                DatePicker("Follow-up Date", selection: $followUpDate, displayedComponents: .date)
                Toggle("Follow-up Completed", isOn: $followUpCompleted)
            }
        }
    }

    private var photoSection: some View {
        Section("Photos") {
            Button(action: {
                showingPhotoSourcePicker = true
            }) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.blue)
                    Text("Add Photos")
                    Spacer()
                    if !selectedImages.isEmpty {
                        Text("\(selectedImages.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            #if os(iOS)
                            Image(uiImage: selectedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .padding(4),
                                    alignment: .topTrailing
                                )
                            #else
                            Image(nsImage: selectedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .padding(4),
                                    alignment: .topTrailing
                                )
                            #endif
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var cattleInfoSection: some View {
        Section {
            HStack {
                Text("Cattle")
                    .foregroundColor(.secondary)
                Spacer()
                Text(cattle.displayName)
                    .fontWeight(.medium)
            }
            HStack {
                Text("Tag Number")
                    .foregroundColor(.secondary)
                Spacer()
                Text(cattle.tagNumber ?? "N/A")
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Save

    private func saveRecord() {
        let record = HealthRecord.create(for: cattle, type: recordType, in: viewContext)

        record.date = date
        record.condition = selectedCondition?.name
        record.treatment = treatment.isEmpty ? nil : treatment
        record.medication = medication.isEmpty ? nil : medication
        record.dosage = dosage.isEmpty ? nil : dosage
        record.veterinarian = veterinarian.isEmpty ? nil : veterinarian
        record.notes = notes.isEmpty ? nil : notes

        // Cost
        if recordCost, let costValue = Decimal(string: cost) {
            record.cost = NSDecimalNumber(decimal: costValue)
        }

        // Treatment Plan - set both ID and relationship
        if let treatmentPlan = selectedTreatmentPlan {
            record.treatmentPlanId = treatmentPlan.id
            record.treatmentPlan = treatmentPlan
            // When using a treatment plan, don't set follow_up_date on health record
            // Completion is tracked via individual tasks (matching web app behavior)
            record.followUpDate = nil
            record.followUpCompleted = false
            print("✅ Set treatment plan: \(treatmentPlan.name ?? "Unknown"), ID: \(treatmentPlan.id?.uuidString ?? "nil")")
            print("📅 Treatment plan selected - follow-up tracking via tasks, not health record fields")
        } else {
            // Only use health record follow-up fields when NO treatment plan is selected
            if needsFollowUp {
                record.followUpDate = followUpDate
                record.followUpCompleted = false
                print("📅 Manual follow-up set: date=\(followUpDate)")
            } else {
                // No follow-up needed
                record.followUpDate = nil
                record.followUpCompleted = false
                print("📅 No follow-up needed")
            }
        }

        // Add photos
        for (index, image) in selectedImages.enumerated() {
            let photo = Photo.create(for: record, in: viewContext)
            photo.setThumbnail(from: image)
            photo.isPrimary = (index == 0) // First photo is primary
            photo.caption = nil
        }

        // Create tasks BEFORE saving so everything is in one transaction
        if let treatmentPlan = selectedTreatmentPlan {
            createTasksForTreatmentSteps(record: record, treatmentPlan: treatmentPlan, saveContext: false)
        }

        do {
            // Log what we're about to save
            print("💾 Saving health record with values:")
            print("  - ID: \(record.id?.uuidString ?? "nil")")
            print("  - Date: \(record.date?.description ?? "nil")")
            print("  - Condition: \(record.condition ?? "nil")")
            print("  - Treatment Plan ID: \(record.treatmentPlanId?.uuidString ?? "nil")")
            print("  - Follow-up Date: \(record.followUpDate?.description ?? "nil")")
            print("  - Follow-up Completed: \(record.followUpCompleted)")

            // Save everything in ONE transaction (health record + photos + tasks)
            try viewContext.save()
            print("✅ Health record and tasks saved successfully in one transaction")

            // Call callback if provided, otherwise just dismiss
            if let callback = onRecordSaved {
                callback(record)
            }

            dismiss()
        } catch {
            errorMessage = "Failed to save record: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Load Health Conditions

    private func loadHealthConditions() {
        isLoadingConditions = true

        _Concurrency.Task {
            do {
                // Fetch health conditions directly from Supabase
                guard SupabaseConfig.isConfigured else {
                    print("⚠️ Supabase not configured, skipping health conditions load")
                    isLoadingConditions = false
                    return
                }

                struct HealthConditionRow: Decodable {
                    let id: UUID
                    let name: String
                    let description: String?
                }

                let response: [HealthConditionRow] = try await SupabaseManager.shared.client
                    .from("health_conditions")
                    .select()
                    .order("name", ascending: true)
                    .execute()
                    .value

                healthConditions = response.map { HealthConditionItem(id: $0.id, name: $0.name, description: $0.description) }
                isLoadingConditions = false
            } catch {
                print("Failed to load health conditions: \(error)")
                isLoadingConditions = false
            }
        }
    }

    // MARK: - Load Treatment Plans

    private func loadTreatmentPlans() {
        isLoadingPlans = true

        _Concurrency.Task {
            do {
                // Just fetch from Core Data without syncing from Supabase
                // This prevents context saves that can cause navigation issues
                // Treatment plans are synced elsewhere in the app
                let fetchRequest: NSFetchRequest<TreatmentPlan> = TreatmentPlan.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TreatmentPlan.name, ascending: true)]

                treatmentPlans = try viewContext.fetch(fetchRequest)
                print("📋 Loaded \(treatmentPlans.count) treatment plans from Core Data")
                filterTreatmentPlans()
                isLoadingPlans = false
            } catch {
                print("❌ Failed to load treatment plans: \(error)")
                isLoadingPlans = false
            }
        }
    }

    // MARK: - Populate Treatment Details

    private func populateTreatmentDetails(from plan: TreatmentPlan) {
        do {
            // Get all steps from the treatment plan
            let fetchRequest: NSFetchRequest<TreatmentPlanStep> = TreatmentPlanStep.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "treatmentPlan.id == %@", plan.id! as CVarArg)
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TreatmentPlanStep.dayNumber, ascending: true)]

            let steps = try viewContext.fetch(fetchRequest)

            // Store steps for display
            treatmentPlanSteps = steps
            print("📋 Loaded \(steps.count) treatment plan steps for display")

            if let firstStep = steps.first {
                print("📋 Auto-populating from treatment plan first step:")

                // Populate treatment field
                if let title = firstStep.title, !title.isEmpty, treatment.isEmpty {
                    treatment = title
                    print("  - Treatment: \(title)")
                }

                // Populate medication field
                if let med = firstStep.medication, !med.isEmpty, medication.isEmpty {
                    medication = med
                    print("  - Medication: \(med)")
                }

                // Populate dosage field
                if let dose = firstStep.dosage, !dose.isEmpty, dosage.isEmpty {
                    dosage = dose
                    print("  - Dosage: \(dose)")
                }
            }

            // NOTE: When using a treatment plan, we do NOT set follow_up_date on the health record
            // Treatment plan completion is tracked via individual tasks, not the health record's follow_up fields
            // This matches the web app behavior and ensures cross-platform consistency
            print("📅 Treatment plan selected - follow-up tracking will use individual tasks")

        } catch {
            print("❌ Failed to fetch treatment plan steps: \(error)")
        }
    }

    // MARK: - Filter Treatment Plans

    private func filterTreatmentPlans() {
        guard let condition = selectedCondition else {
            filteredTreatmentPlans = []
            print("📋 No condition selected, cleared filtered plans")
            return
        }

        // Filter treatment plans by selected condition
        filteredTreatmentPlans = treatmentPlans.filter { plan in
            plan.condition == condition.name
        }
        print("📋 Filtered to \(filteredTreatmentPlans.count) plans for condition: \(condition.name)")

        // Log all treatment plan conditions to help debug
        if filteredTreatmentPlans.isEmpty && !treatmentPlans.isEmpty {
            print("⚠️ No plans matched condition '\(condition.name)'. Available conditions:")
            let uniqueConditions = Set(treatmentPlans.compactMap { $0.condition })
            for c in uniqueConditions {
                print("  - '\(c)'")
            }
        }
    }

    // MARK: - Create Tasks

    private func createTasksForTreatmentSteps(record: HealthRecord, treatmentPlan: TreatmentPlan, saveContext: Bool = true) {
        do {
            // Get treatment plan steps
            let fetchRequest: NSFetchRequest<TreatmentPlanStep> = TreatmentPlanStep.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "treatmentPlan.id == %@", treatmentPlan.id! as CVarArg)
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TreatmentPlanStep.dayNumber, ascending: true)]

            let steps = try viewContext.fetch(fetchRequest)
            print("📋 Found \(steps.count) treatment plan steps")

            // Skip day 0 steps (already completed/in progress) - only create tasks for follow-up steps
            // This matches web app behavior
            let followUpSteps = steps.filter { Int($0.dayNumber) > 0 }
            print("📋 Creating tasks for \(followUpSteps.count) follow-up steps (skipping day 0)")

            // Get current user ID for tasks (from AutoSyncService or defaults)
            let currentUserId = UserDefaults.standard.string(forKey: "currentUserId").flatMap { UUID(uuidString: $0) }

            // Create tasks for follow-up steps only
            for step in followUpSteps {
                let task = Task(context: viewContext)
                task.id = UUID()

                // Set user ID if available
                if let userId = currentUserId {
                    task.assignedToId = userId
                }

                // Calculate due date
                let dayNumber = Int(step.dayNumber)
                let dueDate = Calendar.current.date(byAdding: .day, value: dayNumber, to: date) ?? date

                // Build task details
                let conditionName = selectedCondition?.name ?? "Unknown"
                let cattleTag = cattle.tagNumber ?? cattle.name ?? "Unknown"

                task.title = "\(conditionName): \(step.title ?? "Treatment Step") - \(cattleTag)"

                var description = "\(treatmentPlan.name ?? "Treatment Plan") - \(step.title ?? "Step")\n\n"
                if let stepDesc = step.stepDescription, !stepDesc.isEmpty {
                    description += "\(stepDesc)\n\n"
                }

                // Use step-specific medication/dosage if available, otherwise use health record values
                let stepMedication = step.medication ?? medication
                let stepDosage = step.dosage ?? dosage

                if !stepMedication.isEmpty {
                    description += "Medication: \(stepMedication)\n"
                }
                if !stepDosage.isEmpty {
                    description += "Dosage: \(stepDosage)\n"
                }
                if let notes = step.notes, !notes.isEmpty {
                    description += "\nNotes: \(notes)"
                }

                task.taskDescription = description
                task.taskType = "health_followup"
                task.priority = "medium" // All follow-up tasks are medium priority
                task.status = "pending"
                task.dueDate = dueDate
                task.cattle = cattle
                task.healthRecord = record
                task.createdAt = Date()
                task.updatedAt = Date()

                print("✅ Created task: \(task.title ?? "Untitled") for day \(dayNumber) - Priority: \(task.priority ?? "?")")
            }

            if saveContext {
                try viewContext.save()
                print("✅ Successfully saved \(followUpSteps.count) follow-up tasks to Core Data")
                print("📤 Tasks will be synced to Supabase by AutoSync")
            } else {
                print("✅ Created \(followUpSteps.count) follow-up tasks (will be saved with health record)")
            }
        } catch {
            print("❌ Failed to create tasks for treatment steps: \(error)")
        }
    }
}

// MARK: - Treatment Step Preview

struct TreatmentStepPreview: View {
    let step: TreatmentPlanStep
    let recordDate: Date

    private var stepDate: Date {
        let dayNumber = Int(step.dayNumber)
        return Calendar.current.date(byAdding: .day, value: dayNumber, to: recordDate) ?? recordDate
    }

    private var isToday: Bool {
        Int(step.dayNumber) == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with day badge and date
            HStack {
                // Day badge
                Text("Day \(step.dayNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isToday ? Color.blue : Color.gray)
                    .cornerRadius(6)

                // Date
                Text(formatDate(stepDate))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if isToday {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }

            // Step title
            Text(step.title ?? "Step \(step.stepNumber)")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Step description
            if let description = step.stepDescription, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Medication info
            if let medication = step.medication, !medication.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "pills.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(medication)
                        .font(.caption)
                    if let dosage = step.dosage, !dosage.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(dosage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Notes
            if let notes = step.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(isToday ? Color.blue.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    AddHealthRecordView(cattle: {
        let context = PersistenceController.preview.container.viewContext
        let cattle = Cattle.create(in: context)
        cattle.tagNumber = "LHF-001"
        cattle.name = "Test Cow"
        return cattle
    }())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
