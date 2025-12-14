//
//  MoreView.swift
//  LilyHillFarm
//
//  More menu containing Settings, Tasks, and Contacts
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        List {
                // Marc AI Section
                Section {
                    NavigationLink(destination: ChatHistoryView(
                        supabaseManager: SupabaseManager.shared,
                        aiService: AIService(supabaseManager: SupabaseManager.shared)
                    )) {
                        HStack {
                            Image("marc-avatar")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())

                            Text("Marc Conversations")
                        }
                    }
                } header: {
                    Text("AI Assistant")
                }

                // Management Section
                Section {
                    NavigationLink(destination: BreedingDashboardView()) {
                        Label("Breeding", systemImage: "heart.circle")
                    }

                    NavigationLink(destination: TasksListView()) {
                        Label("Tasks", systemImage: "checklist")
                    }

                    NavigationLink(destination: PastureListView()) {
                        Label("Pastures", systemImage: "map")
                    }

                    NavigationLink(destination: FarmMapView()) {
                        Label("Farm Map", systemImage: "map.fill")
                    }
                } header: {
                    Text("Management")
                }

                // Contacts Section
                Section {
                    NavigationLink(destination: ContactsListView()) {
                        Label("Contacts", systemImage: "person.2.fill")
                    }

                    NavigationLink(destination: TreatmentPlansListView()) {
                        Label("Treatment Plans", systemImage: "list.clipboard")
                    }
                } header: {
                    Text("Resources")
                }

                // Settings Section
                Section {
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gearshape")
                    }
                } header: {
                    Text("App")
                }
            }
        #if os(iOS)
        .listStyle(InsetGroupedListStyle())
        #endif
        .navigationTitle("More")
    }
}

#Preview {
    MoreView()
}
