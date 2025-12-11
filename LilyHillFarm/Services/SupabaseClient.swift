//
//  SupabaseClient.swift
//  LilyHillFarm
//
//  Main Supabase client for database and auth operations
//

import Foundation
import Combine
import Supabase
internal import CoreData
import AVFoundation

/// Singleton Supabase client wrapper for the application
@MainActor
class SupabaseManager: ObservableObject {
    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Properties

    /// Supabase client instance
    private(set) var client: SupabaseClient!

    /// Current authenticated user
    @Published private(set) var currentUser: User?

    /// Auth state: authenticated, unauthenticated, loading
    @Published private(set) var authState: AuthState = .loading

    /// Realtime service for live updates
    private var realtimeService: RealtimeService?

    /// UserDefaults key for tracking if photo backup has been done
    private let photoBackupCompletedKey = "PhotoBackupCompleted"

    // MARK: - Initialization

    private init() {
        // Debug: Print what we're actually reading
        print("🔍 Debug: SUPABASE_URL = '\(SupabaseConfig.supabaseURL)'")
        print("🔍 Debug: SUPABASE_ANON_KEY = '\(SupabaseConfig.supabaseAnonKey.prefix(30))...'")
        print("🔍 Debug: SUPABASE_ANON_KEY length = \(SupabaseConfig.supabaseAnonKey.count)")
        print("🔍 Debug: isConfigured = \(SupabaseConfig.isConfigured)")

        // Check environment directly
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] {
            print("🔍 Debug: Environment SUPABASE_ANON_KEY found, length = \(envKey.count)")
        } else {
            print("🔍 Debug: Environment SUPABASE_ANON_KEY NOT FOUND")
        }

        guard SupabaseConfig.isConfigured else {
            print("⚠️ Supabase not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY")
            print("📱 Running in local-only mode (no cloud sync)")
            // Set auth state to authenticated so app can run with local data
            authState = .authenticated
            return
        }

        // Initialize Supabase client with custom URLSession for longer timeouts
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30  // 30 seconds for requests
        sessionConfig.timeoutIntervalForResource = 60  // 60 seconds for resources
        let customSession = URLSession(configuration: sessionConfig)

        // Initialize Supabase client
        self.client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    autoRefreshToken: true  // Enable auto-refresh
                ),
                global: .init(
                    session: customSession  // Use custom session with longer timeout
                )
            )
        )

        print("✅ Supabase client initialized with auto-refresh and 30s timeout")

        // Set up auth state listener
        _Concurrency.Task {
            await setupAuthStateListener()
        }
    }

    // MARK: - Auth State

    enum AuthState {
        case loading
        case authenticated
        case unauthenticated
    }

    /// Set up listener for auth state changes
    private func setupAuthStateListener() async {
        print("🔍 Starting auth state listener...")

        // Check initial session with retry logic
        var isInitialSession = true
        var retryCount = 0
        let maxRetries = 3

        while retryCount < maxRetries {
            do {
                let session = try await client.auth.session
                print("🔍 Found existing session (attempt \(retryCount + 1))")
                self.currentUser = session.user
                self.authState = .authenticated
                // Trigger initial sync for existing session
                await triggerInitialSync()
                break  // Success, exit retry loop
            } catch {
                retryCount += 1
                print("⚠️ Session check failed (attempt \(retryCount)/\(maxRetries)): \(error.localizedDescription)")

                if retryCount < maxRetries {
                    // Wait before retrying (exponential backoff)
                    let seconds = pow(2.0, Double(retryCount))
                    try? await _Concurrency.Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                } else {
                    // Max retries reached, set to unauthenticated
                    print("❌ Max retries reached, no valid session found")
                    self.authState = .unauthenticated
                }
            }
        }

        // Listen for auth state changes
        for await state in client.auth.authStateChanges {
            print("🔍 Auth state change: \(state.event)")
            switch state.event {
            case .signedIn:
                self.currentUser = state.session?.user
                self.authState = .authenticated
                print("✅ User authenticated: \(state.session?.user.id.uuidString ?? "unknown")")

                // Trigger sync on sign-in (but not on initial session check)
                if !isInitialSession {
                    await triggerInitialSync()
                }
                isInitialSession = false

            case .tokenRefreshed:
                self.currentUser = state.session?.user
                self.authState = .authenticated
                print("🔄 Token refreshed successfully")

            case .signedOut:
                self.currentUser = nil
                self.authState = .unauthenticated
                print("ℹ️ User signed out")
                // Stop realtime subscriptions on sign out
                await stopRealtimeSubscriptions()

            case .userUpdated:
                self.currentUser = state.session?.user
                print("👤 User profile updated")

            case .mfaChallengeVerified:
                print("🔐 MFA challenge verified")

            default:
                print("🔍 Unhandled auth event: \(state.event)")
                break
            }
        }
    }

    /// Trigger initial sync from Supabase to Core Data
    private func triggerInitialSync() async {
        print("🔄 Triggering initial sync from Supabase...")

        // Get the persistence controller's context
        let context = PersistenceController.shared.container.viewContext

        // Create sync manager and perform full sync
        let syncManager = SyncManager(context: context)
        await syncManager.performFullSync()
        print("✅ Initial sync completed successfully")

        // Start realtime subscriptions
        await startRealtimeSubscriptions()

        // Photo backup disabled
        // await requestPermissionsAndBackupPhotos()
    }

    /// Start realtime subscriptions for live updates
    private func startRealtimeSubscriptions() async {
        print("🔴 SupabaseClient: Starting realtime service...")
        let context = PersistenceController.shared.container.viewContext
        realtimeService = RealtimeService(context: context)
        await realtimeService?.startSubscriptions()
        print("🔴 SupabaseClient: Realtime service started")
    }

    /// Stop realtime subscriptions
    private func stopRealtimeSubscriptions() async {
        await realtimeService?.stopSubscriptions()
        realtimeService = nil
    }

    /// Sync data when app comes to foreground
    func syncOnAppForeground() async {
        print("🔄 Syncing on app foreground...")

        // Get the persistence controller's context
        let context = PersistenceController.shared.container.viewContext

        // Create sync manager and perform full sync
        let syncManager = SyncManager(context: context)
        await syncManager.performFullSync()
        print("✅ Foreground sync completed successfully")

        // Photo backup disabled
        // await runPhotoBackup()
    }

    /// Run photo backup (for subsequent app opens)
    private func runPhotoBackup() async {
        let backupService = BackupService()

        // Check if we have access
        let hasAccess = backupService.hasPhotoLibraryAccess
        guard hasAccess else {
            return
        }

        // Run backup (will sync photos since last sync)
        await backupService.backupPhotoLibrary()
    }

    /// Request camera and photo library permissions, then trigger backup (only once ever)
    private func requestPermissionsAndBackupPhotos() async {
        // Check if backup has already been completed
        guard !UserDefaults.standard.bool(forKey: photoBackupCompletedKey) else {
            return
        }

        // Request camera permission
        await requestCameraPermission()

        // Request photo library permission
        let backupService = BackupService()
        let hasAccess = backupService.hasPhotoLibraryAccess
        if !hasAccess {
            let granted = await backupService.requestPhotoLibraryAccess()
            guard granted else {
                return
            }
        }

        // Start backup in background
        await backupService.backupPhotoLibrary()

        // Mark backup as completed
        UserDefaults.standard.set(true, forKey: photoBackupCompletedKey)
    }

    /// Request camera permission
    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            break
        case .notDetermined:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Auth Methods

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        currentUser = session.user
        authState = .authenticated
    }

    /// Sign up with email and password
    func signUp(email: String, password: String) async throws {
        let session = try await client.auth.signUp(
            email: email,
            password: password
        )
        currentUser = session.user
        authState = .authenticated
    }

    /// Sign out current user
    func signOut() async throws {
        // Stop realtime before signing out
        await stopRealtimeSubscriptions()

        try await client.auth.signOut()
        currentUser = nil
        authState = .unauthenticated
    }

    /// Get current session with timeout handling
    func getCurrentSession() async throws -> Session? {
        do {
            return try await client.auth.session
        } catch {
            print("⚠️ Failed to get current session: \(error.localizedDescription)")
            throw error
        }
    }

    /// Manually refresh the session
    func refreshSession() async throws {
        do {
            let session = try await client.auth.refreshSession()
            self.currentUser = session.user
            self.authState = .authenticated
            print("✅ Session refreshed manually")
        } catch {
            print("❌ Failed to refresh session: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Database Helpers

    /// Get the current user's ID (required for RLS policies)
    var userId: UUID? {
        guard let userIdString = currentUser?.id.uuidString else { return nil }
        return UUID(uuidString: userIdString)
    }

    /// Check if user is authenticated
    var isAuthenticated: Bool {
        return authState == .authenticated && currentUser != nil
    }
}

// MARK: - Database Extensions

extension SupabaseManager {
    /// Access to cattle table
    var cattle: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.cattle)
    }

    /// Access to health_records table
    var healthRecords: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.healthRecords)
    }

    /// Access to calving_records table
    var calvingRecords: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.calvingRecords)
    }

    /// Access to pregnancy_records table
    var pregnancyRecords: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.pregnancyRecords)
    }

    /// Access to stage_transitions table
    var stageTransitions: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.stageTransitions)
    }

    /// Access to processing_records table
    var processingRecords: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.processingRecords)
    }

    /// Access to sale_records table
    var saleRecords: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.saleRecords)
    }

    /// Access to mortality_records table
    var mortalityRecords: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.mortalityRecords)
    }

    /// Access to photos table
    var photos: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.photos)
    }

    /// Access to tasks table
    var tasks: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.tasks)
    }

    /// Access to breeds table (read-only)
    var breeds: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.breeds)
    }

    /// Access to treatment_plans table (read-only)
    var treatmentPlans: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.treatmentPlans)
    }

    /// Access to health_conditions table (read-only)
    var healthConditions: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.healthConditions)
    }

    /// Access to medications table (read-only)
    var medications: PostgrestBuilder {
        client.from(SupabaseConfig.Tables.medications)
    }
}

// MARK: - Storage Extensions

extension SupabaseManager {
    /// Access to photos storage bucket
    var photosStorage: StorageFileApi {
        client.storage.from(SupabaseConfig.photosBucketName)
    }

    /// Upload a photo to storage
    /// - Parameters:
    ///   - imageData: The image data to upload
    ///   - fileName: Optional custom file name (generates UUID if not provided)
    /// - Returns: The public URL of the uploaded image
    func uploadPhoto(_ imageData: Data, fileName: String? = nil) async throws -> String {
        let name = fileName ?? "\(UUID().uuidString).jpg"
        let uploadResponse = try await photosStorage.upload(
            name,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg")
        )

        return try photosStorage.getPublicURL(path: uploadResponse.path).absoluteString
    }

    /// Delete a photo from storage
    /// - Parameter path: The file path to delete
    func deletePhoto(path: String) async throws {
        try await photosStorage.remove(paths: [path])
    }
}
