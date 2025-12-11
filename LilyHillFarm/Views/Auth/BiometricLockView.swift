//
//  BiometricLockView.swift
//  LilyHillFarm
//
//  View displayed when app is locked with biometric authentication
//

import SwiftUI

struct BiometricLockView: View {
    @ObservedObject var authManager: BiometricAuthManager
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            // Blurred background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App logo/icon
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("LilyHillFarm")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Your cattle management is secured")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Authentication button
                VStack(spacing: 20) {
                    if let error = authManager.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        authenticate()
                    }) {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: authManager.biometricType.icon)
                                    .font(.title3)
                                Text("Unlock with \(authManager.biometricType.displayName)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Auto-trigger authentication when view appears
            authenticate()
        }
    }

    private func authenticate() {
        isAuthenticating = true

        _Concurrency.Task {
            let _ = await authManager.authenticate()
            await MainActor.run {
                isAuthenticating = false
            }
        }
    }
}

#Preview {
    BiometricLockView(authManager: BiometricAuthManager())
}
