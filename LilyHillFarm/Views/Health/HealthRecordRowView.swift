//
//  HealthRecordRowView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct HealthRecordRowView: View {
    @ObservedObject var record: HealthRecord

    var typeIcon: String {
        guard let type = HealthRecordType(rawValue: record.recordType ?? "") else {
            return "heart.text.square"
        }

        switch type {
        case .vaccination:
            return "syringe"
        case .treatment:
            return "pills"
        case .checkup:
            return "stethoscope"
        case .injury:
            return "bandage"
        case .illness:
            return "cross.case"
        case .surgery:
            return "bandage.fill"
        case .dental:
            return "mouth"
        case .other:
            return "heart.text.square"
        }
    }

    var typeColor: Color {
        guard let type = HealthRecordType(rawValue: record.recordType ?? "") else {
            return .gray
        }

        switch type {
        case .vaccination:
            return .green
        case .treatment:
            return .blue
        case .checkup:
            return .purple
        case .injury:
            return .orange
        case .illness:
            return .red
        case .surgery:
            return .red
        case .dental:
            return .cyan
        case .other:
            return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: typeIcon)
                    .font(.title3)
                    .foregroundColor(typeColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Type with condition
                Text(record.displayTypeWithCondition)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Treatment detail if present
                if let treatment = record.treatment, !treatment.isEmpty {
                    Text(treatment)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Date
                HStack(spacing: 8) {
                    Label(record.displayDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Cost if present
                    if let cost = record.cost as? Decimal, cost > 0 {
                        Label("$\(cost as NSNumber)", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Treatment plan indicator
                if record.treatmentPlanId != nil {
                    Label("Treatment plan", systemImage: "list.clipboard")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                // Follow-up indicator
                if record.isFollowUpOverdue {
                    Label("Follow-up overdue", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if record.isFollowUpNeeded {
                    if let days = record.daysUntilFollowUp {
                        Label("Follow-up in \(days) day\(days == 1 ? "" : "s")", systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Photo indicator
            if !record.sortedPhotos.isEmpty {
                VStack {
                    Image(systemName: "photo.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(record.sortedPhotos.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        HealthRecordRowView(record: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            let record = HealthRecord.create(for: cattle, type: .vaccination, in: context)
            record.condition = "Annual vaccination"
            record.date = Date()
            return record
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
