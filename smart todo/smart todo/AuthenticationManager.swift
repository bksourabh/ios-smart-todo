//
//  AuthenticationManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import Foundation
import AuthenticationServices
import SwiftUI
import Combine

@MainActor
final class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()

    @Published var isAuthenticated: Bool = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var userId: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let userIdKey = "appleUserId"
    private let userNameKey = "appleUserName"
    private let userEmailKey = "appleUserEmail"

    override init() {
        super.init()
        checkExistingCredentials()
    }

    // Check if user is already signed in
    func checkExistingCredentials() {
        if let userId = UserDefaults.standard.string(forKey: userIdKey), !userId.isEmpty {
            // Verify the credential is still valid
            let provider = ASAuthorizationAppleIDProvider()
            let userNameKeyLocal = userNameKey
            let userEmailKeyLocal = userEmailKey
            provider.getCredentialState(forUserID: userId) { [weak self] state, error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    switch state {
                    case .authorized:
                        self.isAuthenticated = true
                        self.userId = userId
                        self.userName = UserDefaults.standard.string(forKey: userNameKeyLocal) ?? ""
                        self.userEmail = UserDefaults.standard.string(forKey: userEmailKeyLocal) ?? ""
                    case .revoked, .notFound:
                        self.signOut()
                    case .transferred:
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
    }

    // Sign in with Apple
    func signInWithApple() {
        isLoading = true
        errorMessage = nil

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    // Sign out
    func signOut() {
        isAuthenticated = false
        userId = ""
        userName = ""
        userEmail = ""

        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
    }

    // Save user credentials
    private func saveCredentials(userId: String, name: String, email: String) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
        UserDefaults.standard.set(name, forKey: userNameKey)
        UserDefaults.standard.set(email, forKey: userEmailKey)

        self.userId = userId
        self.userName = name
        self.userEmail = email
        self.isAuthenticated = true
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            isLoading = false

            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userId = appleIDCredential.user

                // Get name (only provided on first sign-in)
                var fullName = ""
                if let givenName = appleIDCredential.fullName?.givenName {
                    fullName = givenName
                    if let familyName = appleIDCredential.fullName?.familyName {
                        fullName += " " + familyName
                    }
                }

                // If name is empty, try to get from stored value
                if fullName.isEmpty {
                    fullName = UserDefaults.standard.string(forKey: userNameKey) ?? ""
                }

                // Get email (only provided on first sign-in)
                let email = appleIDCredential.email ?? UserDefaults.standard.string(forKey: userEmailKey) ?? ""

                saveCredentials(userId: userId, name: fullName, email: email)
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            isLoading = false

            if let authError = error as? ASAuthorizationError {
                if authError.code == .canceled {
                    // User canceled, don't show error
                } else if authError.code == .failed {
                    errorMessage = "Sign in failed. Please try again."
                } else if authError.code == .invalidResponse {
                    errorMessage = "Invalid response from Apple. Please try again."
                } else if authError.code == .notHandled {
                    errorMessage = "Sign in request was not handled."
                } else if authError.code == .notInteractive {
                    errorMessage = "Sign in requires user interaction."
                } else {
                    errorMessage = "An unexpected error occurred."
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Sign In With Apple Button View

struct SignInWithAppleButtonView: View {
    @ObservedObject var authManager: AuthenticationManager

    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                switch result {
                case .success(let authorization):
                    handleAuthorization(authorization)
                case .failure(let error):
                    authManager.errorMessage = error.localizedDescription
                }
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(10)
    }

    private func handleAuthorization(_ authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userId = appleIDCredential.user

            var fullName = ""
            if let givenName = appleIDCredential.fullName?.givenName {
                fullName = givenName
                if let familyName = appleIDCredential.fullName?.familyName {
                    fullName += " " + familyName
                }
            }

            let email = appleIDCredential.email ?? ""

            // Save to UserDefaults
            UserDefaults.standard.set(userId, forKey: "appleUserId")
            if !fullName.isEmpty {
                UserDefaults.standard.set(fullName, forKey: "appleUserName")
            }
            if !email.isEmpty {
                UserDefaults.standard.set(email, forKey: "appleUserEmail")
            }

            authManager.userId = userId
            authManager.userName = fullName.isEmpty ? UserDefaults.standard.string(forKey: "appleUserName") ?? "" : fullName
            authManager.userEmail = email.isEmpty ? UserDefaults.standard.string(forKey: "appleUserEmail") ?? "" : email
            authManager.isAuthenticated = true
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @ObservedObject var authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon and title
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Smart Todo")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Organize your tasks with smart notifications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Sign in section
            VStack(spacing: 20) {
                SignInWithAppleButtonView(authManager: authManager)
                    .padding(.horizontal, 40)

                if authManager.isLoading {
                    ProgressView()
                        .padding(.top, 10)
                }

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Text("Sign in to sync your tasks across devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 60)
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - User Profile View (for showing signed-in user info)

struct UserProfileView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Text(initials)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if !authManager.userName.isEmpty {
                                Text(authManager.userName)
                                    .font(.headline)
                            }
                            if !authManager.userEmail.isEmpty {
                                Text(authManager.userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(role: .destructive) {
                        authManager.signOut()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var initials: String {
        let names = authManager.userName.split(separator: " ")
        if names.count >= 2 {
            return String(names[0].prefix(1)) + String(names[1].prefix(1))
        } else if let first = names.first {
            return String(first.prefix(2))
        }
        return "U"
    }
}
