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
                    // Run sync asynchronously with low priority to avoid blocking UI
                    _Concurrency.Task(priority: .background) {
                        // Small delay to let UI settle first
                        try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        await supabase.syncOnAppForeground()
                    }
                }
            } else if newPhase == .background {
                // App went to background - save Core Data if needed
                persistenceController.saveContext()
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
                LoadingView()
            case .authenticated:
                ContentView()
            case .unauthenticated:
                AuthView()
            }
        }
    }
}

// MARK: - Loading View with Logo

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image("LHF - Logo 2 (circle)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)

                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
