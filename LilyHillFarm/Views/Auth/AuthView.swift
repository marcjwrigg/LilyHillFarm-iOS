//
//  AuthView.swift
//  LilyHillFarm
//
//  Authentication view for Supabase login/signup
//

import SwiftUI

struct AuthView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Logo/Header
                VStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                }
                .padding(.top, 60)

                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .frame(height: 50)

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(isSignUp ? .newPassword : .password)
                        .frame(height: 50)
                }
                .padding(.horizontal, 40)

                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: handleAuth) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .padding(.horizontal, 40)
                }

                Spacer()

                // Configuration warning
                if !SupabaseConfig.isConfigured {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Supabase not configured")
                            .font(.caption)
                        Text("Please set SUPABASE_URL and SUPABASE_ANON_KEY")
                            .font(.caption2)
                    }
                    .padding()
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func handleAuth() {
        _Concurrency.Task {
            await performAuth()
        }
    }

    @MainActor
    private func performAuth() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await supabase.signUp(email: email, password: password)
            } else {
                try await supabase.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Auth error: \(error)")
        }

        isLoading = false
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
}
