//
//  HealthRecordListView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct HealthRecordListView: View {
    @ObservedObject var cattle: Cattle
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddRecord = false
    @State private var selectedRecordType: LegacyHealthRecordType? = nil
    @State private var recordToNavigateTo: HealthRecord?
    @State private var navigateToDetail = false

    var filteredRecords: [HealthRecord] {
        if let type = selectedRecordType {
            return cattle.sortedHealthRecords.filter { $0.recordType == type.rawValue }
        }
        return cattle.sortedHealthRecords
    }

    var upcomingCount: Int {
        cattle.upcomingHealthAppointments.count
    }

    var overdueCount: Int {
        cattle.overdueHealthAppointments.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Alert Banner
            if upcomingCount > 0 || overdueCount > 0 {
                VStack(spacing: 8) {
                    if overdueCount > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(overdueCount) overdue follow-up\(overdueCount == 1 ? "" : "s")")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }

                    if upcomingCount > 0 {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                            Text("\(upcomingCount) upcoming follow-up\(upcomingCount == 1 ? "" : "s")")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }

            // Filter by type
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedRecordType == nil,
                        action: { selectedRecordType = nil }
                    )

                    ForEach(LegacyHealthRecordType.allCases) { type in
                        FilterChip(
                            title: type.rawValue,
                            isSelected: selectedRecordType == type,
                            action: { selectedRecordType = type }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            Divider()

            // Records count
            HStack {
                Text("\(filteredRecords.count) record\(filteredRecords.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Records list
            if filteredRecords.isEmpty {
                EmptyStateView(
                    icon: "heart.text.square",
                    title: "No health records",
                    message: selectedRecordType == nil ?
                        "Add the first health record for \(cattle.displayName)" :
                        "No \(selectedRecordType!.rawValue.lowercased()) records found"
                )
            } else {
                List {
                    ForEach(filteredRecords, id: \.objectID) { record in
                        NavigationLink(destination: HealthRecordDetailView(record: record)) {
                            HealthRecordRowView(record: record)
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Health Records")
    #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
    #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingAddRecord = true }) {
                    Label("Add Record", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            AddHealthRecordView(cattle: cattle) { savedRecord in
                // After saving, navigate to the detail view
                recordToNavigateTo = savedRecord
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigateToDetail = true
                }
            }
        }
        .navigationDestination(isPresented: $navigateToDetail) {
            if let record = recordToNavigateTo {
                HealthRecordDetailView(record: record)
            }
        }
    }

    // MARK: - Delete

    private func deleteRecords(at offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredRecords[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                print("Error deleting records: \(error)")
            }
        }
    }
}

#Preview {
    NavigationView {
        HealthRecordListView(cattle: {
            let context = PersistenceController.preview.container.viewContext
            let cattle = Cattle.create(in: context)
            cattle.tagNumber = "LHF-001"
            cattle.name = "Test Cow"
            return cattle
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
