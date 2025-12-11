//
//  MoreView.swift
//  LilyHillFarm
//
//  More menu containing Settings, Tasks, and Contacts
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationView {
            List {
                // Tasks Section
                Section {
                    NavigationLink(destination: TasksListView()) {
                        Label("Tasks", systemImage: "checklist")
                    }
                } header: {
                    Text("Management")
                }

                // Contacts Section
                Section {
                    NavigationLink(destination: ContactsListView()) {
                        Label("Contacts", systemImage: "person.2.fill")
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
}

#Preview {
    MoreView()
}
