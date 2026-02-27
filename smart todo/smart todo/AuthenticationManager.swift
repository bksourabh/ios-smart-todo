//
//  AuthenticationManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import Foundation
import AuthenticationServices
import CoreData
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

    // Delete account — clears all local data and signs out
    func deleteAccount() {
        let context = PersistenceController.shared.container.viewContext

        // Delete all Core Data entities
        let entityNames = ["TodoTask", "Group", "PointOfInterest"]
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try? context.execute(batchDelete)
        }
        try? context.save()

        // Clear all UserDefaults
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
        }

        signOut()
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
        .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
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
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.05),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon with animation
                VStack(spacing: 28) {
                    ZStack {
                        // Animated circles
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 160, height: 160)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 130, height: 130)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 12) {
                        Text("Smart Todo")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("Intelligent task management with\nlocation & time-based reminders")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                Spacer()

                // Features preview
                VStack(spacing: 16) {
                    featureRow(icon: "bell.badge.fill", color: .orange, text: "Smart notifications")
                    featureRow(icon: "location.fill", color: .purple, text: "Location-based alerts")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

                // Sign in section
                VStack(spacing: 16) {
                    SignInWithAppleButtonView(authManager: authManager)
                        .frame(height: 54)
                        .padding(.horizontal, 32)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                    if authManager.isLoading {
                        ProgressView()
                            .padding(.top, 8)
                    }

                    if let error = authManager.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 32)
                    }

                    Text("Your data is private and secure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - User Profile View (for showing signed-in user info)

struct UserProfileView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingSettings = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        NavigationView {
            List {
                // Profile Header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 70, height: 70)

                            Text(initials)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            if !authManager.userName.isEmpty {
                                Text(authManager.userName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            } else {
                                Text("Smart Todo User")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }

                            if !authManager.userEmail.isEmpty {
                                Text(authManager.userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                Text("Apple ID verified")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 12)
                }

                // Settings Section
                Section {
                    NavigationLink(destination: SettingsView()) {
                        Label {
                            Text("Notifications")
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.orange)
                        }
                    }

                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label {
                            HStack {
                                Text("Location Settings")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "location.fill")
                                .foregroundColor(.purple)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Settings")
                }

                // Support Section
                Section {
                    Link(destination: URL(string: "https://github.com/bksourabh/ios-smart-todo/issues")!) {
                        Label {
                            HStack {
                                Text("Send Feedback")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)

                    Label {
                        HStack {
                            Text("App Version")
                            Spacer()
                            Text(appVersion)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.gray)
                    }
                } header: {
                    Text("About")
                }

                // Sign Out Section
                Section {
                    Button(action: {
                        showingSignOutAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }

                // Delete Account Section
                Section {
                    Button(action: {
                        showingDeleteAccountAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Deleting your account will permanently erase all your tasks, locations, and app data from this device.\n\nMade with care for productivity enthusiasts")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Sign Out?", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("You will need to sign in again to access your tasks.")
            }
            .alert("Delete Account?", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    authManager.deleteAccount()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete all your tasks, locations, and app data from this device. This action cannot be undone.")
            }
        }
        .navigationViewStyle(.stack)
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
