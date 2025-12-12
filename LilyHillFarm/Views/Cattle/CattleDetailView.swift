//
//  CattleDetailView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct CattleDetailView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditSheet = false
    @State private var showingPromoteSheet = false
    @State private var showingPhotoPicker = false
    @State private var showingPhotoGallery = false
    @State private var showingSaleSheet = false
    @State private var showingDeceasedSheet = false
    @State private var showingEditProcessing = false
    @State private var showingPhotoSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingHeroImage = false
    @State private var showingAddHealthRecord = false
    @State private var showingFamilyTree = false

    // Section expansion states
    @State private var isBasicInfoExpanded = true
    @State private var isBreedingExpanded = true
    @State private var isHealthExpanded = true
    @State private var isLifecycleExpanded = true
    @State private var isLineageExpanded = true
    @State private var isNotesExpanded = true
    @State private var isPhotosExpanded = true
    @State private var isStageHistoryExpanded = false
    @State private var isExitActionsExpanded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with photo
                headerSection

                // Basic Information Card
                InfoCard(title: "Basic Information", isExpanded: $isBasicInfoExpanded) {
                    InfoRow(label: "Tag Number", value: cattle.tagNumber ?? "N/A")
                    InfoRow(label: "Name", value: cattle.name ?? "Not set")
                    InfoRow(label: "Sex", value: cattle.sex ?? "N/A")
                    InfoRow(label: "Breed", value: cattle.breed?.name ?? "Unknown")
                    InfoRow(label: "Type", value: cattle.cattleType ?? "N/A")
                    InfoRow(label: "Color", value: cattle.color ?? "Not recorded")
                    if let markings = cattle.markings, !markings.isEmpty {
                        InfoRow(label: "Markings", value: markings)
                    }
                    if let weight = cattle.currentWeight as? Decimal, weight > 0 {
                        InfoRow(label: "Current Weight", value: "\(weight as NSNumber) lbs")
                    } else {
                        InfoRow(label: "Current Weight", value: "Not recorded")
                    }
                }

                // Breeding & Calving Card (for cows/heifers only)
                if cattle.sex == CattleSex.cow.rawValue || cattle.sex == CattleSex.heifer.rawValue {
                    InfoCard(title: "Breeding & Calving", isExpanded: $isBreedingExpanded) {
                        // Pending breeding
                        if let pendingBreeding = cattle.pendingBreeding {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.indigo)
                                    Text("Scheduled AI Breeding")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.indigo)
                                    Spacer()
                                    Text("Pending")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.indigo.opacity(0.2))
                                        .foregroundColor(.indigo)
                                        .cornerRadius(4)
                                }

                                Divider()

                                // Breeding date and method
                                VStack(alignment: .leading, spacing: 6) {
                                    if let breedingDate = pendingBreeding.breedingDate {
                                        HStack {
                                            Image(systemName: "calendar")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Planned Breeding Date:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(breedingDate.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    }

                                    if let method = pendingBreeding.breedingMethod {
                                        HStack {
                                            Image(systemName: "syringe")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Method:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(method)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    }
                                }

                                // Sire information
                                if let sire = pendingBreeding.bull {
                                    HStack {
                                        Image(systemName: "pawprint")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Sire:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(sire.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                } else if let externalBull = pendingBreeding.externalBullName, !externalBull.isEmpty {
                                    HStack {
                                        Image(systemName: "pawprint")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Sire:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(externalBull)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }

                                // AI Protocol Steps
                                if let notes = pendingBreeding.notes, !notes.isEmpty {
                                    Divider()

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "list.clipboard")
                                                .font(.subheadline)
                                                .foregroundColor(.indigo)
                                            Text("AI Protocol Steps")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.indigo)
                                        }

                                        // Try to detect protocol from notes
                                        if let aiProtocol = detectAIProtocol(from: notes) {
                                            AIProtocolStepsView(aiProtocol: aiProtocol, startDate: pendingBreeding.breedingStartDate ?? pendingBreeding.breedingDate)
                                        } else {
                                            // Fall back to showing notes as text
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.white.opacity(0.5))
                                                .cornerRadius(6)
                                        }
                                    }
                                }

                                // AI Technician
                                if let aiTech = pendingBreeding.aiTechnician, !aiTech.isEmpty {
                                    HStack {
                                        Image(systemName: "person")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("AI Technician:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(aiTech)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Active pregnancy (only one should be active)
                        if let currentPregnancy = cattle.currentPregnancy {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "heart.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Active Pregnancy")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    Spacer()
                                    // Show breeding status badge
                                    if let status = currentPregnancy.status {
                                        Text(status.capitalized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(status == "confirmed" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                            .foregroundColor(status == "confirmed" ? .green : .orange)
                                            .cornerRadius(4)
                                    }
                                }

                                if let days = currentPregnancy.daysUntilDue {
                                    if days < 0 {
                                        Text("\(-days) days overdue")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else {
                                        Text("Due in \(days) days")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }

                                // Breeding date
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Bred:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(currentPregnancy.displayBreedingDate)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }

                                // Breeding method
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.text.square")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Method:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(currentPregnancy.displayMethod)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }

                                // Sire information
                                if let sire = currentPregnancy.bull {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pawprint")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Sire:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(sire.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        if let breed = sire.breed?.name {
                                            Text("(\(breed))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } else if let externalBull = currentPregnancy.externalBullName, !externalBull.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pawprint")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Sire:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(externalBull)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("(AI Bull)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                // AI Technician if available
                                if let aiTech = currentPregnancy.aiTechnician, !aiTech.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("AI Tech:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(aiTech)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Summary counts
                        HStack {
                            Text("Total Calvings")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(cattle.sortedCalvingRecords.count)")
                                .fontWeight(.semibold)
                        }

                        let previousPregnancies = cattle.sortedPregnancyRecords.filter {
                            $0.status == PregnancyStatus.calved.rawValue
                        }
                        HStack {
                            Text("Previous Pregnancies")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(previousPregnancies.count)")
                                .fontWeight(.semibold)
                        }

                        // Breeding Statistics
                        if cattle.sortedCalvingRecords.count > 0 {
                            Divider()

                            // Bull:Heifer Ratio
                            let bulls = cattle.offspringArray.filter { $0.sex == CattleSex.bull.rawValue || $0.sex == CattleSex.steer.rawValue }.count
                            let heifers = cattle.offspringArray.filter { $0.sex == CattleSex.heifer.rawValue || $0.sex == CattleSex.cow.rawValue }.count
                            let ratioText: String = {
                                if heifers > 0 {
                                    let ratio = Double(bulls) / Double(heifers)
                                    return "\(bulls):\(heifers) (\(String(format: "%.2f", ratio)):1)"
                                } else if bulls > 0 {
                                    return "\(bulls):0"
                                } else {
                                    return "—"
                                }
                            }()

                            HStack {
                                Text("Bull:Heifer Ratio")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(ratioText)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.indigo)
                            }

                            // Avg Days Post Partum
                            let avgDaysPostPartum: Int? = {
                                var intervals: [Int] = []
                                let calvings = cattle.sortedCalvingRecords
                                let pregnancies = cattle.sortedPregnancyRecords.sorted {
                                    ($0.breedingDate ?? Date.distantPast) < ($1.breedingDate ?? Date.distantPast)
                                }

                                for calving in calvings {
                                    guard let calvingDate = calving.calvingDate else { continue }

                                    if let nextBreeding = pregnancies.first(where: { pregnancy in
                                        guard let breedingDate = pregnancy.breedingDate else { return false }
                                        return breedingDate > calvingDate
                                    }) {
                                        let days = Calendar.current.dateComponents([.day], from: calvingDate, to: nextBreeding.breedingDate!).day ?? 0
                                        if days > 0 && days < 365 {
                                            intervals.append(days)
                                        }
                                    }
                                }

                                return intervals.isEmpty ? nil : intervals.reduce(0, +) / intervals.count
                            }()

                            if let avgDays = avgDaysPostPartum {
                                HStack {
                                    Text("Avg Days Post Partum")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(avgDays)")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                            }

                            // Avg Days Between Calving
                            let avgDaysBetweenCalving: Int? = {
                                let calvingDates = cattle.sortedCalvingRecords.reversed()
                                    .compactMap { $0.calvingDate }
                                guard calvingDates.count > 1 else { return nil }

                                var intervals: [Int] = []
                                for i in 1..<calvingDates.count {
                                    let days = Calendar.current.dateComponents([.day], from: calvingDates[i-1], to: calvingDates[i]).day ?? 0
                                    if days > 0 {
                                        intervals.append(days)
                                    }
                                }

                                return intervals.isEmpty ? nil : intervals.reduce(0, +) / intervals.count
                            }()

                            if let avgDays = avgDaysBetweenCalving {
                                HStack {
                                    Text("Avg Days Between Calving")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(avgDays)")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.purple)
                                }
                            }
                        }

                        // Latest calving
                        if let latestCalving = cattle.sortedCalvingRecords.first {
                            Divider()
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundColor(.pink)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Latest Calving")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let calf = latestCalving.calf {
                                        Text("Calf: \(calf.displayName)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Text(latestCalving.displayDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }

                        // View all button
                        NavigationLink(destination: PregnancyListView(cattle: cattle)) {
                            HStack {
                                Image(systemName: "heart.circle")
                                Text("View Breeding Records")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }

                // Health Summary Card
                InfoCard(title: "Health", isExpanded: $isHealthExpanded) {
                    HStack {
                        Text("Total Records")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(cattle.sortedHealthRecords.count)")
                            .fontWeight(.semibold)
                    }

                    if !cattle.upcomingHealthAppointments.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("\(cattle.upcomingHealthAppointments.count) upcoming")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }

                    if !cattle.overdueHealthAppointments.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(cattle.overdueHealthAppointments.count) overdue")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }

                    // Latest health record
                    if let latestRecord = cattle.sortedHealthRecords.first {
                        Divider()
                        HStack(spacing: 12) {
                            Image(systemName: latestRecord.typeIcon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Latest Record")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(latestRecord.displayTypeWithCondition)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(latestRecord.displayDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }

                    // Add health record button
                    Button(action: {
                        print("🔘 Add Health Record button tapped")
                        showingAddHealthRecord = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Health Record")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle()) // Use borderless to prevent tap bleed-through
                    .padding(.top, 8)
                    .padding(.bottom, 8) // Add bottom padding to separate from NavigationLink

                    Divider() // Add visual and tap separation

                    // View all button
                    NavigationLink(destination: HealthRecordListView(cattle: cattle)) {
                        HStack {
                            Image(systemName: "heart.text.square")
                            Text("View All Health Records")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                // Lifecycle Card
                InfoCard(title: "Lifecycle", isExpanded: $isLifecycleExpanded) {
                    HStack {
                        Text("Current Stage")
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 8) {
                            if let stage = cattle.currentStage {
                                StageBadge(stage: stage)
                                Text(stage)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    InfoRow(label: "Status", value: cattle.currentStatus ?? "Unknown")
                    InfoRow(label: "Production Path", value: cattle.productionPath ?? "Unknown")
                    InfoRow(label: "Age", value: cattle.age)

                    if let dob = cattle.dateOfBirth {
                        InfoRow(label: "Date of Birth", value: formatDate(dob))
                    }

                    // Promote button
                    if cattle.canPromoteToNextStage(), let nextStage = cattle.nextStage() {
                        Button(action: { showingPromoteSheet = true }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Promote to \(nextStage.displayName)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }

                // Processing Record Card
                if let processingRecord = cattle.processingRecord {
                    InfoCard(title: "Processing Information") {
                        if let date = processingRecord.processingDate {
                            InfoRow(label: "Processing Date", value: formatDate(date))
                        }

                        if let processor = processingRecord.processor {
                            InfoRow(label: "Processor", value: processor)
                        }

                        if let liveWeight = processingRecord.liveWeight as? Decimal, liveWeight > 0 {
                            InfoRow(label: "Live Weight", value: "\(liveWeight as NSNumber) lbs")
                        }

                        if let hangingWeight = processingRecord.hangingWeight as? Decimal, hangingWeight > 0 {
                            InfoRow(label: "Hanging Weight", value: "\(hangingWeight as NSNumber) lbs")
                        }

                        if let dressPercentage = processingRecord.dressPercentage as? Decimal, dressPercentage > 0 {
                            InfoRow(label: "Dress %", value: String(format: "%.1f%%", NSDecimalNumber(decimal: dressPercentage).doubleValue))
                        }

                        if let cost = processingRecord.processingCost as? Decimal, cost > 0 {
                            InfoRow(label: "Processing Cost", value: String(format: "$%.2f", NSDecimalNumber(decimal: cost).doubleValue))
                        }

                        if let notes = processingRecord.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(notes)
                                    .font(.subheadline)
                            }
                            .padding(.top, 4)
                        }

                        Button(action: { showingEditProcessing = true }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Processing Details")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }

                // Lineage & Offspring Card
                if cattle.dam != nil || cattle.sire != nil || !cattle.offspringAsSire.isEmpty || !cattle.offspringArray.isEmpty {
                    InfoCard(title: "Lineage & Offspring", isExpanded: $isLineageExpanded) {
                        // Parents section
                        if cattle.dam != nil || cattle.sire != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Parents")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                if let dam = cattle.dam {
                                    NavigationLink(destination: CattleDetailView(cattle: dam)) {
                                        HStack {
                                            Text("Dam")
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(dam.displayName)
                                                .foregroundColor(.primary)
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                if let sire = cattle.sire {
                                    NavigationLink(destination: CattleDetailView(cattle: sire)) {
                                        HStack {
                                            Text("Sire")
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(sire.displayName)
                                                .foregroundColor(.primary)
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        // Offspring section
                        if !cattle.offspringAsSire.isEmpty || !cattle.offspringArray.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                let totalOffspring = cattle.offspringAsSire.count + cattle.offspringArray.count
                                Text("Offspring (\(totalOffspring))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.top, cattle.dam != nil || cattle.sire != nil ? 12 : 0)

                                // Show offspring as Dam
                                if !cattle.offspringArray.isEmpty {
                                    Text("As Dam (\(cattle.offspringArray.count))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ForEach(cattle.offspringArray.prefix(3), id: \.objectID) { calf in
                                        NavigationLink(destination: CattleDetailView(cattle: calf)) {
                                            HStack {
                                                Text(calf.displayName)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }

                                    if cattle.offspringArray.count > 3 {
                                        Text("+ \(cattle.offspringArray.count - 3) more")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 4)
                                    }
                                }

                                // Show offspring as Sire
                                if !cattle.offspringAsSire.isEmpty {
                                    Text("As Sire (\(cattle.offspringAsSire.count))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, !cattle.offspringArray.isEmpty ? 8 : 0)

                                    ForEach(cattle.offspringAsSire.prefix(3), id: \.objectID) { calf in
                                        NavigationLink(destination: CattleDetailView(cattle: calf)) {
                                            HStack {
                                                Text(calf.displayName)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }

                                    if cattle.offspringAsSire.count > 3 {
                                        Text("+ \(cattle.offspringAsSire.count - 3) more")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 4)
                                    }
                                }

                                // View all offspring button
                                if totalOffspring > 0 {
                                    NavigationLink(destination: OffspringListView(cattle: cattle)) {
                                        HStack {
                                            Image(systemName: "heart")
                                            Text("View All Offspring")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // View Family Tree button
                        Button(action: { showingFamilyTree = true }) {
                            HStack {
                                Image(systemName: "circle.hexagonpath")
                                Text("View Family Tree")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }

                // Notes Card
                InfoCard(title: "Notes", isExpanded: $isNotesExpanded) {
                    if let notes = cattle.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.bottom, 8)
                    } else {
                        Text("No notes added")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.bottom, 8)
                    }

                    Button(action: { showingEditSheet = true }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text(cattle.notes?.isEmpty ?? true ? "Add Notes" : "Edit Notes")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                // Photos Card
                InfoCard(title: "Photos", isExpanded: $isPhotosExpanded) {
                    if cattle.sortedPhotos.isEmpty {
                        // Empty state with add button
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("No Photos")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Add photos to visually identify this animal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: { showingPhotoSourcePicker = true }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Add Photos")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        HStack {
                            Text("Total Photos")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(cattle.sortedPhotos.count)")
                                .fontWeight(.semibold)
                        }

                        Divider()

                        // Photo preview grid (first 6)
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(cattle.sortedPhotos.prefix(6), id: \.objectID) { photo in
                                #if os(iOS)
                                if let image = photo.thumbnailImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                                        .frame(width: 80, height: 80)
                                }
                                #elseif os(macOS)
                                if let image = photo.thumbnailImage {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                                        .frame(width: 80, height: 80)
                                }
                                #endif
                            }
                        }
                        .padding(.top, 8)

                        if cattle.sortedPhotos.count > 6 {
                            Text("+ \(cattle.sortedPhotos.count - 6) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }

                        // Action buttons
                        HStack(spacing: 12) {
                            Button(action: { showingPhotoSourcePicker = true }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Add")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: { showingPhotoGallery = true }) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("View All")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8)
                    }
                }

                // Stage History
                if !cattle.sortedStageTransitions.isEmpty {
                    InfoCard(title: "Stage History", isExpanded: $isStageHistoryExpanded) {
                        ForEach(cattle.sortedStageTransitions, id: \.objectID) { transition in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(transition.displayFromStage)
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                        Text(transition.displayToStage)
                                            .fontWeight(.semibold)
                                    }
                                    .font(.subheadline)

                                    Text(transition.displayDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if let weight = transition.displayWeight {
                                    Text(weight)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Exit Actions (only for active animals)
                if cattle.currentStatus == CattleStatus.active.rawValue {
                    InfoCard(title: "Exit Actions", isExpanded: $isExitActionsExpanded) {
                        VStack(spacing: 12) {
                            Button(action: { showingSaleSheet = true }) {
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                    Text("Record Sale")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            Button(action: { showingDeceasedSheet = true }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Record Death")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            #if os(macOS)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
        }
        .navigationTitle(cattle.displayName)
        .id(cattle.id) // Maintain view identity even when object updates
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingEditSheet = true }) {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCattleView(cattle: cattle)
        }
        .sheet(isPresented: $showingPromoteSheet) {
            if let nextStage = cattle.nextStage() {
                if nextStage == LegacyCattleStage.processed {
                    RecordProcessingView(cattle: cattle)
                } else {
                    PromoteStageView(cattle: cattle, toStage: nextStage)
                }
            }
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
                savePhotos([image])
            }
            #endif
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            #if os(iOS)
            PhotosLibraryPicker(maxSelection: 10) { images in
                savePhotos(images)
            }
            #endif
        }
        .sheet(isPresented: $showingPhotoPicker) {
            #if os(iOS)
            PhotoPickerView { images in
                savePhotos(images)
            }
            #else
            PhotoPickerView { images in
                savePhotos(images)
            }
            #endif
        }
        .sheet(isPresented: $showingPhotoGallery) {
            NavigationView {
                PhotoGalleryView(
                    photos: cattle.sortedPhotos,
                    entityName: cattle.displayName,
                    onAddPhoto: {
                        showingPhotoGallery = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingPhotoPicker = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingHeroImage) {
            if let primaryPhoto = cattle.primaryPhoto {
                PhotoDetailView(photo: primaryPhoto)
            }
        }
        .sheet(isPresented: $showingSaleSheet) {
            RecordSaleView(cattle: cattle)
        }
        .sheet(isPresented: $showingDeceasedSheet) {
            RecordDeceasedView(cattle: cattle)
        }
        .sheet(isPresented: $showingEditProcessing) {
            if let processingRecord = cattle.processingRecord {
                EditProcessingView(processingRecord: processingRecord)
            }
        }
        .sheet(isPresented: $showingAddHealthRecord) {
            NavigationStack {
                AddHealthRecordView(cattle: cattle) { savedRecord in
                    // Callback after saving - just refresh the view
                    print("✅ Health record saved, staying on cattle detail view")
                    // The sheet will dismiss automatically, and we'll stay on this view
                }
            }
        }
        .sheet(isPresented: $showingFamilyTree) {
            FamilyTreeView(cattle: cattle)
        }
    }

    // MARK: - Photo Management

    #if os(iOS)
    private func savePhotos(_ images: [UIImage]) {
        for image in images {
            let photo = Photo.create(for: cattle, in: viewContext)
            photo.setThumbnail(from: image)

            // Set first photo as primary if no primary exists
            if cattle.primaryPhoto == nil {
                photo.isPrimary = true
            }
        }

        do {
            try viewContext.save()
        } catch {
            print("Error saving photos: \(error)")
        }
    }
    #elseif os(macOS)
    private func savePhotos(_ images: [NSImage]) {
        for image in images {
            let photo = Photo.create(for: cattle, in: viewContext)
            photo.setThumbnail(from: image)

            // Set first photo as primary if no primary exists
            if cattle.primaryPhoto == nil {
                photo.isPrimary = true
            }
        }

        do {
            try viewContext.save()
        } catch {
            print("Error saving photos: \(error)")
        }
    }
    #endif

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Primary photo
            if let photo = cattle.primaryPhoto,
               let thumbnailImage = photo.thumbnailImage {
                #if os(iOS)
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 300)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(8),
                        alignment: .bottomTrailing
                    )
                    .onTapGesture {
                        showingHeroImage = true
                    }
                #elseif os(macOS)
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 300)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(8),
                        alignment: .bottomTrailing
                    )
                    .onTapGesture {
                        showingHeroImage = true
                    }
                #endif
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                    .frame(height: 300)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }

            // Photo count
            if !cattle.sortedPhotos.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.caption)
                    Text("\(cattle.sortedPhotos.count) photo\(cattle.sortedPhotos.count == 1 ? "" : "s")")
                        .font(.caption)
                    if cattle.primaryPhoto != nil {
                        Text("• Tap to view full size")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helper Functions

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Shared Components
// Note: InfoCard and InfoRow are now defined in SharedComponents.swift

#Preview {
    NavigationView {
        CattleDetailView(cattle: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            cattle.tagNumber = "LHF-001"
            cattle.name = "Bessie"
            cattle.sex = CattleSex.cow.rawValue
            cattle.color = "Black"
            cattle.markings = "White face"
            cattle.currentStage = LegacyCattleStage.weanling.rawValue
            cattle.dateOfBirth = Calendar.current.date(byAdding: .month, value: -8, to: Date())
            cattle.notes = "Healthy and growing well"
            return cattle
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

// MARK: - AI Protocol Helper Functions

/// Detect AI protocol from notes text
func detectAIProtocol(from notes: String) -> AIProtocol? {
    let lowercasedNotes = notes.lowercased()

    if lowercasedNotes.contains("7-day") && lowercasedNotes.contains("co-synch") {
        return getAIProtocol(id: "7_day_cosynch")
    } else if lowercasedNotes.contains("7 & 7") || lowercasedNotes.contains("7 and 7") {
        return getAIProtocol(id: "7_and_7_synch")
    } else if lowercasedNotes.contains("5-day") && lowercasedNotes.contains("co-synch") {
        return getAIProtocol(id: "5_day_cosynch")
    }

    return nil
}

// MARK: - AI Protocol Steps View

struct AIProtocolStepsView: View {
    let aiProtocol: AIProtocol
    let startDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Protocol name
            Text(aiProtocol.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.indigo)

            // Steps
            ForEach(Array(aiProtocol.steps.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: 6) {
                    // Step header with date
                    HStack(alignment: .top, spacing: 8) {
                        // Step number circle
                        ZStack {
                            Circle()
                                .fill(Color.indigo.opacity(0.2))
                                .frame(width: 24, height: 24)
                            Text("\(index + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.indigo)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.caption)
                                .fontWeight(.semibold)

                            if let startDate = startDate {
                                let stepDate = Calendar.current.date(byAdding: .day, value: step.day, to: startDate) ?? startDate
                                Text(stepDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }

                    // Actions
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(step.actions, id: \.self) { action in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(action)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 32)

                    // Notes if present
                    if let notes = step.notes {
                        Text(notes)
                            .font(.caption2)
                            .italic()
                            .foregroundColor(.indigo)
                            .padding(.leading, 32)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.5))
                .cornerRadius(6)
            }
        }
    }
}
