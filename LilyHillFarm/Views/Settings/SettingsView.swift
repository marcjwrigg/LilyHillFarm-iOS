//
//  SettingsView.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var supabase = SupabaseManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Cattle.tagNumber, ascending: true)],
        animation: .default)
    private var cattle: FetchedResults<Cattle>

    @AppStorage("developerModeEnabled") private var showingDeveloperMenu = false
    @State private var developerTapCount = 0
    @State private var resetTapTimer: Timer?
    @State private var showingUnlockMessage = false
    @State private var showingLogoutAlert = false

    var body: some View {
        Form {
                // App Info Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2025.12.02")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("App Name")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            handleVersionTap()
                        }) {
                            HStack(spacing: 4) {
                                Text("🐄 LilyHillFarm")
                                    .fontWeight(.semibold)
                                if developerTapCount > 0 {
                                    Text("(\(developerTapCount)/7)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }

                // Data Section
                Section("Database") {
                    HStack {
                        Text("Total Cattle")
                        Spacer()
                        Text("\(cattle.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Active Cattle")
                        Spacer()
                        Text("\(activeCattleCount)")
                            .foregroundColor(.secondary)
                    }
                }

                // Supabase Sync Section
                Section("Cloud Sync") {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.blue)
                        Text("Supabase")
                        Spacer()
                        Text(SupabaseConfig.isConfigured ? "Configured" : "Not Configured")
                            .foregroundColor(SupabaseConfig.isConfigured ? .green : .orange)
                    }

                    if SupabaseConfig.isConfigured {
                        HStack {
                            Text("Project URL")
                            Spacer()
                            Text(SupabaseConfig.supabaseURL)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Support Section
                Section("Support") {
                    Link(destination: URL(string: "https://github.com/anthropics/claude-code")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Help & Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Account Section
                Section("Account") {
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out")
                        }
                    }
                }

                // Developer Section (hidden until activated)
                if showingDeveloperMenu {
                    Section("Developer") {
                        NavigationLink(destination: DeveloperMenuView()) {
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(.orange)
                                Text("Developer Menu")
                            }
                        }
                    }
                }
        }
        .navigationTitle("Settings")
        .alert("Developer Mode", isPresented: $showingUnlockMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Developer menu unlocked! 🔓\n\nYou can now access developer tools and demo data generation.")
        }
        .alert("Log Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                handleLogout()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }

    // MARK: - Computed Properties

    private var activeCattleCount: Int {
        cattle.filter { $0.currentStatus == CattleStatus.active.rawValue }.count
    }

    // MARK: - Developer Menu Activation

    private func handleVersionTap() {
        developerTapCount += 1

        // Reset timer
        resetTapTimer?.invalidate()
        resetTapTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            developerTapCount = 0
        }

        // Activate developer menu after 7 taps
        if developerTapCount >= 7 {
            if !showingDeveloperMenu {
                showingDeveloperMenu = true
                showingUnlockMessage = true

                #if os(iOS)
                // Haptic feedback on iOS
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
            developerTapCount = 0
        }
    }

    // MARK: - Logout

    private func handleLogout() {
        _Concurrency.Task {
            do {
                try await supabase.signOut()
                print("✅ Successfully logged out")
            } catch {
                print("❌ Logout error: \(error)")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
