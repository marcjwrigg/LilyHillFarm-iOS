//
//  BackupService.swift
//  LilyHillFarm
//
//  Service for backing up device photo library to Supabase Storage
//

import Foundation
import UIKit
import Photos
import Supabase
import Combine
import Network

@MainActor
class BackupService: ObservableObject {
    private let supabase = SupabaseManager.shared
    private let initialBackupLimit = 1000
    private let bucketName = "photos"
    private let lastSyncDateKey = "lastPhotoSyncDate"
    private let backedUpPhotosKey = "backedUpPhotoIdentifiers"

    // MARK: - Farm Access Control

    /// Only allow backup for this specific farm
    private let allowedFarmId = UUID(uuidString: "7d87bf10-6177-443b-88b4-b6e19640a17b")!

    // MARK: - Published Properties

    @Published var isBackingUp = false
    @Published var backupProgress: Double = 0.0
    @Published var backedUpCount: Int = 0
    @Published var totalToBackup: Int = 0
    @Published var lastBackupDate: Date?
    @Published var backupError: String?
    @Published var isWiFiConnected = false

    // MARK: - Network Monitoring

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - UserDefaults Storage

    private var lastSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: lastSyncDateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastSyncDateKey)
            }
        }
    }

    private var backedUpPhotoIdentifiers: Set<String> {
        get {
            if let data = UserDefaults.standard.data(forKey: backedUpPhotosKey),
               let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return set
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: backedUpPhotosKey)
            }
        }
    }

    // MARK: - Initialization

    init() {
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isWiFiConnected = path.usesInterfaceType(.wifi)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func getCurrentUserId() -> String? {
        return supabase.client.auth.currentUser?.id.uuidString
    }

    private func getUserBackupFolder() -> String {
        guard let userId = getCurrentUserId() else {
            return "backup/unknown"
        }
        return "backup/\(userId)"
    }

    /// Check if current user's farm is allowed to use backup service
    private func isBackupAllowedForCurrentUser() async -> Bool {
        guard let userId = supabase.userId else {
            return false
        }

        do {
            // Query farm_users table to get user's farm
            struct FarmUser: Codable {
                let farm_id: UUID
            }

            let farmUsers: [FarmUser] = try await supabase.client
                .from("farm_users")
                .select("farm_id")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let userFarmId = farmUsers.first?.farm_id else {
                return false
            }

            return userFarmId == allowedFarmId

        } catch {
            return false
        }
    }

    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    var hasPhotoLibraryAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    var hasFullPhotoLibraryAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized
    }

    // MARK: - Folder Management

    /// Ensure backup folder exists (no-op since folders are virtual in storage)
    private func ensureBackupFolderExists() async throws {
        // Folders in Supabase Storage are virtual - they're created automatically
        // when you upload a file with a path like "backup/filename.jpg"
    }

    // MARK: - Backup Operations


    func backupPhotoLibrary() async {
        guard !isBackingUp else {
            return
        }

        // Check farm access first
        guard await isBackupAllowedForCurrentUser() else {
            backupError = "Photo backup is not available for your account."
            return
        }

        // Check WiFi connectivity
        guard isWiFiConnected else {
            backupError = "WiFi connection required for photo backup."
            return
        }

        // Check photo library access
        guard hasPhotoLibraryAccess else {
            backupError = "No photo library access. Please grant permission in Settings."
            return
        }

        isBackingUp = true
        backupProgress = 0.0
        backedUpCount = 0
        backupError = nil
        defer { isBackingUp = false }

        do {
            // Get existing backed up identifiers
            var backedUpSet = backedUpPhotoIdentifiers

            // Determine which photos to fetch based on last sync date
            let allPhotos: [PHAsset]
            if let lastSync = lastSyncDate {
                // Subsequent run: fetch photos since last sync
                allPhotos = fetchPhotosSince(date: lastSync)
            } else {
                // First run: fetch last 250 photos
                allPhotos = fetchRecentPhotos(limit: initialBackupLimit)
            }

            // Filter out already backed up photos
            let photosToBackup = allPhotos.filter { !backedUpSet.contains($0.localIdentifier) }

            totalToBackup = photosToBackup.count

            guard totalToBackup > 0 else {
                lastSyncDate = Date()
                return
            }

            for asset in photosToBackup {
                // Check WiFi before each upload
                guard isWiFiConnected else {
                    backupError = "WiFi connection lost. Backup paused."
                    return
                }

                do {
                    try await backupPhoto(asset)
                    backedUpSet.insert(asset.localIdentifier)
                    backedUpPhotoIdentifiers = backedUpSet
                    backedUpCount += 1
                    backupProgress = Double(backedUpCount) / Double(totalToBackup)
                } catch {
                    // Continue with next photo
                }
            }

            // Update sync timestamps only if all photos completed
            if backedUpCount == totalToBackup {
                let now = Date()
                lastBackupDate = now
                lastSyncDate = now
            }

        } catch {
            backupError = error.localizedDescription
        }
    }

    /// Fetch recent photos from device library
    private func fetchRecentPhotos(limit: Int) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let results = PHAsset.fetchAssets(with: fetchOptions)

        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }

    /// Fetch photos created since a specific date
    private func fetchPhotosSince(date: Date) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate > %@",
            PHAssetMediaType.image.rawValue,
            date as NSDate
        )

        let results = PHAsset.fetchAssets(with: fetchOptions)

        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }

    /// Backup a single photo asset to Supabase
    private func backupPhoto(_ asset: PHAsset) async throws {
        // 1. Request image data from asset
        let imageData = try await requestImageData(for: asset)

        // 2. Generate filename using asset's local identifier and creation date
        let creationDate = asset.creationDate ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: creationDate)

        // Clean the local identifier to make it filename-safe
        let cleanIdentifier = asset.localIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .prefix(50) // Limit length

        // Use user-specific folder
        let userFolder = getUserBackupFolder()
        let fileName = "\(userFolder)/\(dateString)_\(cleanIdentifier).jpg"

        // 3. Upload to user's backup folder in photos bucket
        try await uploadToBackupFolder(imageData, fileName: fileName)
    }

    /// Request image data from PHAsset
    private func requestImageData(for asset: PHAsset) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data = data else {
                    continuation.resume(throwing: PhotoBackupError.imageDataUnavailable)
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }


    /// Upload image data to backup folder
    private func uploadToBackupFolder(_ imageData: Data, fileName: String) async throws {
        _ = try await supabase.client.storage
            .from(bucketName)
            .upload(
                path: fileName,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
    }

    // MARK: - Cleanup Operations

    /// Delete all backed up photos from user's backup folder
    func clearBackup() async throws {
        // Check farm access
        guard await isBackupAllowedForCurrentUser() else {
            throw PhotoBackupError.uploadFailed("Photo backup is not available for your account")
        }

        let userFolder = getUserBackupFolder()

        // List all files in user's backup folder
        let files = try await supabase.client.storage
            .from(bucketName)
            .list(path: userFolder)

        guard !files.isEmpty else {
            return
        }

        // Delete all files (include folder path)
        let filePaths = files.map { "\(userFolder)/\($0.name)" }
        try await supabase.client.storage
            .from(bucketName)
            .remove(paths: filePaths)

        lastBackupDate = nil
        lastSyncDate = nil
        backedUpPhotoIdentifiers = []
    }

    /// Get backup statistics for user's folder
    func getBackupStats() async throws -> BackupStats {
        // Check farm access
        guard await isBackupAllowedForCurrentUser() else {
            throw PhotoBackupError.uploadFailed("Photo backup is not available for your account")
        }

        let userFolder = getUserBackupFolder()

        let files = try await supabase.client.storage
            .from(bucketName)
            .list(path: userFolder)

        let totalSize = files.reduce(0) { $0 + ($1.metadata?["size"] as? Int ?? 0) }

        return BackupStats(
            fileCount: files.count,
            totalSize: totalSize,
            lastBackup: lastBackupDate
        )
    }
}

// MARK: - Models

struct BackupStats {
    let fileCount: Int
    let totalSize: Int
    let lastBackup: Date?

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
}

// MARK: - Errors

enum PhotoBackupError: LocalizedError {
    case noPhotoLibraryAccess
    case imageDataUnavailable
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noPhotoLibraryAccess:
            return "No photo library access"
        case .imageDataUnavailable:
            return "Could not retrieve image data"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}
