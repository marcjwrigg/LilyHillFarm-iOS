//
//  LilyHillFarmApp.swift
//  LilyHillFarm
//
//  Created by Marc Wrigglesworth on 12/2/25.
//

import SwiftUI
internal import CoreData

@main
struct LilyHillFarmApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var supabase = SupabaseManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Seed initial data (breeds) on first launch
        SeedDataService.shared.seedDataIfNeeded(in: persistenceController.container.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(supabase)
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                // App became active - trigger sync if authenticated
                if supabase.authState == .authenticated {
                    _Concurrency.Task {
                        await supabase.syncOnAppForeground()
                    }
                }
            }
        }
    }
}

// MARK: - Root View with Auth Check

struct RootView: View {
    @EnvironmentObject var supabase: SupabaseManager

    var body: some View {
        Group {
            switch supabase.authState {
            case .loading:
                ProgressView("Loading...")
            case .authenticated:
                ContentView()
            case .unauthenticated:
                AuthView()
            }
        }
    }
}
