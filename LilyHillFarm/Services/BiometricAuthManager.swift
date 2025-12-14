//
//  BiometricAuthManager.swift
//  LilyHillFarm
//
//  Manager for handling biometric authentication (Face ID/Touch ID)
//

import Foundation
import LocalAuthentication
import SwiftUI
import Combine 

@MainActor
class BiometricAuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var biometricType: BiometricType = .none
    @Published var authError: String?

    // User defaults keys
    private let biometricEnabledKey = "biometricAuthEnabled"

    // MARK: - Biometric Type

    enum BiometricType {
        case faceID
        case touchID
        case none

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "None"
            }
        }

        var icon: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .none: return "lock"
            }
        }
    }

    // MARK: - Initialization

    init() {
        checkBiometricType()
        // Don't auto-authenticate on init - let the app control when to authenticate
    }

    // MARK: - Settings

    var isBiometricEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: biometricEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: biometricEnabledKey)

            // If disabling, automatically authenticate
            if !newValue {
                isAuthenticated = true
            }
        }
    }

    // MARK: - Biometric Availability

    func checkBiometricType() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }

        switch context.biometryType {
        case .faceID:
            biometricType = .faceID
        case .touchID:
            biometricType = .touchID
        case .none:
            biometricType = .none
        case .opticID:
            biometricType = .none // Or handle opticID if needed
        @unknown default:
            biometricType = .none
        }
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometricUnavailableReason: String? {
        let context = LAContext()
        var error: NSError?

        guard !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }

        guard let error = error else {
            return "Unknown error"
        }

        switch error.code {
        case LAError.biometryNotEnrolled.rawValue:
            return "\(biometricType.displayName) is not set up on this device"
        case LAError.biometryNotAvailable.rawValue:
            return "\(biometricType.displayName) is not available on this device"
        case LAError.biometryLockout.rawValue:
            return "\(biometricType.displayName) is locked. Please use your device passcode."
        default:
            return error.localizedDescription
        }
    }

    // MARK: - Authentication

    func authenticate(reason: String = "Authenticate to access LilyHillFarm") async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            await MainActor.run {
                if let error = error {
                    authError = error.localizedDescription
                }
                // If biometrics not available, fall back to allowing access
                isAuthenticated = true
            }
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            await MainActor.run {
                isAuthenticated = success
                authError = nil
            }

            return success
        } catch let error as LAError {
            await MainActor.run {
                isAuthenticated = false

                switch error.code {
                case .userCancel:
                    authError = "Authentication cancelled"
                case .userFallback:
                    authError = "User chose to use passcode"
                case .biometryNotAvailable:
                    authError = "\(biometricType.displayName) not available"
                case .biometryNotEnrolled:
                    authError = "\(biometricType.displayName) not set up"
                case .biometryLockout:
                    authError = "\(biometricType.displayName) locked. Use passcode."
                default:
                    authError = error.localizedDescription
                }
            }

            return false
        } catch {
            await MainActor.run {
                isAuthenticated = false
                authError = error.localizedDescription
            }

            return false
        }
    }

    /// Reset authentication state (for app backgrounding)
    func lockApp() {
        if isBiometricEnabled {
            isAuthenticated = false
            authError = nil
        }
    }

    /// Check if authentication is required
    func requiresAuthentication() -> Bool {
        return isBiometricEnabled && !isAuthenticated
    }
}
