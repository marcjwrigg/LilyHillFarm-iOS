//
//  PregnancyRowView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct PregnancyRowView: View {
    @ObservedObject var pregnancy: PregnancyRecord

    var statusColor: Color {
        guard let status = PregnancyStatus(rawValue: pregnancy.status ?? "") else {
            return .gray
        }

        switch status {
        case .pending:
            return .indigo
        case .bred:
            return .orange
        case .exposed:
            return .yellow
        case .confirmed:
            return .green
        case .open:
            return .gray
        case .calved:
            return .blue
        case .lost:
            return .red
        }
    }

    var statusIcon: String {
        guard let status = PregnancyStatus(rawValue: pregnancy.status ?? "") else {
            return "questionmark.circle"
        }

        switch status {
        case .pending:
            return "calendar.badge.clock"
        case .bred:
            return "heart"
        case .exposed:
            return "heart.circle"
        case .confirmed:
            return "checkmark.circle.fill"
        case .open:
            return "circle"
        case .calved:
            return "heart.circle.fill"
        case .lost:
            return "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundColor(statusColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Status
                Text(pregnancy.displayStatus)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Sire
                if let sire = pregnancy.bull {
                    Text("Sire: \(sire.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unknown Sire")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Dates
                HStack(spacing: 8) {
                    Label(pregnancy.displayBreedingDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if pregnancy.expectedCalvingDate != nil {
                        Label(pregnancy.displayDueDate, systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Due date indicator
                if let days = pregnancy.daysUntilDue {
                    if days < 0 {
                        Label("\(-days) days overdue", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if days <= 30 {
                        Label("Due in \(days) days", systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Photo indicator
            if !pregnancy.sortedPhotos.isEmpty {
                VStack {
                    Image(systemName: "photo.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(pregnancy.sortedPhotos.count)")
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
        PregnancyRowView(pregnancy: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            let pregnancy = PregnancyRecord.create(for: cattle, method: .natural, in: context)
            pregnancy.status = PregnancyStatus.confirmed.rawValue
            pregnancy.breedingDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())
            pregnancy.expectedCalvingDate = Calendar.current.date(byAdding: .day, value: 183, to: pregnancy.breedingDate!)
            return pregnancy
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
