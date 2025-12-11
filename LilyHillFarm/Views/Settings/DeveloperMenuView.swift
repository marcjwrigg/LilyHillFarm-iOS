//
//  DeveloperMenuView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct DeveloperMenuView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingGenerateAlert = false
    @State private var showingClearAlert = false
    @State private var isGenerating = false
    @State private var resultMessage = ""
    @State private var showingResult = false

    var body: some View {
        Form {
            Section("Demo Data") {
                Button(action: { showingGenerateAlert = true }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Generate Demo Data")
                                .fontWeight(.semibold)
                            Text("Creates sample cattle with records")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(isGenerating)

                if isGenerating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Database") {
                Button(role: .destructive, action: { showingClearAlert = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        VStack(alignment: .leading) {
                            Text("Clear All Data")
                                .fontWeight(.semibold)
                            Text("Deletes all cattle and records")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Supabase Sync") {
                Button(action: triggerSupabaseSync) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Pull from Supabase")
                                .fontWeight(.semibold)
                            Text("Download records from server")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Button(action: triggerPushToSupabase) {
                    HStack {
                        Image(systemName: "arrow.up.circle")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Push to Supabase")
                                .fontWeight(.semibold)
                            Text("Upload all local records to server")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Developer Menu")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Generate Demo Data", isPresented: $showingGenerateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Generate") {
                generateDemoData()
            }
        } message: {
            Text("This will create 15 Angus cattle with various health records, pregnancies, and calving records. Existing data will not be affected.")
        }
        .alert("Clear All Data", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all cattle, health records, pregnancy records, calving records, and photos. This action cannot be undone.")
        }
        .alert("Success", isPresented: $showingResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: - Actions

    private func generateDemoData() {
        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            let generator = DemoDataGenerator(context: viewContext)

            do {
                try generator.generateCompleteHerd()

                DispatchQueue.main.async {
                    isGenerating = false
                    resultMessage = "Successfully generated demo data with 15 cattle, health records, pregnancies, and calving records."
                    showingResult = true
                }
            } catch {
                DispatchQueue.main.async {
                    isGenerating = false
                    resultMessage = "Error generating demo data: \(error.localizedDescription)"
                    showingResult = true
                }
            }
        }
    }

    private func clearAllData() {
        let entities = ["Cattle", "HealthRecord", "PregnancyRecord", "CalvingRecord", "StageTransition", "Photo", "Breed"]

        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try viewContext.execute(deleteRequest)
            } catch {
                print("Error deleting \(entityName): \(error)")
            }
        }

        do {
            try viewContext.save()
            resultMessage = "All data cleared successfully."
            showingResult = true
        } catch {
            resultMessage = "Error clearing data: \(error.localizedDescription)"
            showingResult = true
        }
    }

    private func triggerSupabaseSync() {
        // Trigger Supabase sync (pull from server)
        _Concurrency.Task {
            let syncManager = SyncManager(context: viewContext)
            await syncManager.performFullSync()
            resultMessage = "Pull from Supabase completed. Check console for sync status."
            showingResult = true
        }
    }

    private func triggerPushToSupabase() {
        // Push all local records to Supabase
        _Concurrency.Task {
            let syncManager = SyncManager(context: viewContext)
            await syncManager.pushToServer()
            resultMessage = "Push to Supabase completed. All local records have been uploaded to the server."
            showingResult = true
        }
    }
}

#Preview {
    NavigationView {
        DeveloperMenuView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
