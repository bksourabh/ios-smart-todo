//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Sourabh Mazumder on 8/3/2026.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication

class ShareViewController: UIViewController {

    private var hasProcessed = false
    private let appGroupID = "group.com.helpingthoughtgames.smart-todo"
    private let sharedAuthKey = "sharedAppleUserId"
    private let sharedUserNameKey = "sharedAppleUserName"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasProcessed else { return }
        hasProcessed = true
        verifyAuthAndProceed()
    }

    // MARK: - Auth Verification

    private func verifyAuthAndProceed() {
        // Step 1: Check if user has an active Smart Todo profile
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID),
              let userId = sharedDefaults.string(forKey: sharedAuthKey),
              !userId.isEmpty else {
            showNoProfileView()
            return
        }

        let userName = sharedDefaults.string(forKey: sharedUserNameKey) ?? "User"

        // Step 2: Authenticate with Face ID / Touch ID
        authenticateWithBiometrics(userName: userName)
    }

    private func authenticateWithBiometrics(userName: String) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available — fall back to device passcode
            authenticateWithPasscode(userName: userName)
            return
        }

        let reason = "Authenticate to import notes into Smart Todo"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    self?.extractText()
                } else if let laError = authError as? LAError, laError.code == .userFallback {
                    // User tapped "Enter Password"
                    self?.authenticateWithPasscode(userName: userName)
                } else {
                    self?.showAuthFailedView()
                }
            }
        }
    }

    private func authenticateWithPasscode(userName: String) {
        let context = LAContext()
        let reason = "Authenticate to import notes into Smart Todo"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, _ in
            DispatchQueue.main.async {
                if success {
                    self?.extractText()
                } else {
                    self?.showAuthFailedView()
                }
            }
        }
    }

    // MARK: - Error Views

    private func showNoProfileView() {
        let errorView = ShareAuthErrorView(
            icon: "person.crop.circle.badge.exclamationmark",
            title: "No Smart Todo Profile",
            message: "Please open Smart Todo and sign in with your Apple ID before using the Share Extension.",
            buttonTitle: "OK",
            onDismiss: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        )
        showHostedView(errorView)
    }

    private func showAuthFailedView() {
        let errorView = ShareAuthErrorView(
            icon: "faceid",
            title: "Authentication Failed",
            message: "Face ID or passcode authentication is required to import notes into Smart Todo.",
            buttonTitle: "Cancel",
            onRetry: { [weak self] in
                self?.hasProcessed = false
                self?.removeHostedView()
                self?.verifyAuthAndProceed()
            },
            onDismiss: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        )
        showHostedView(errorView)
    }

    // MARK: - Text Extraction

    private func extractText() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showAnalyzer(with: "")
            return
        }

        let queue = DispatchQueue(label: "com.smarttodo.share.textcollection")
        var collectedTexts: [String] = []
        let group = DispatchGroup()

        for item in extensionItems {
            if let attributedText = item.attributedContentText {
                let text = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    collectedTexts.append(text)
                }
            }

            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                        if let text = data as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            queue.sync { collectedTexts.append(text) }
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                        if let url = data as? URL {
                            queue.sync { collectedTexts.append(url.absoluteString) }
                        } else if let text = data as? String {
                            queue.sync { collectedTexts.append(text) }
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            let snapshot = queue.sync { collectedTexts }
            let unique = self?.deduplicateTexts(snapshot) ?? []
            let fullText = unique.joined(separator: "\n")
            self?.showAnalyzer(with: fullText)
        }
    }

    private func deduplicateTexts(_ texts: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !seen.contains(trimmed) {
                seen.insert(trimmed)
                result.append(trimmed)
            }
        }
        return result
    }

    // MARK: - View Hosting

    private func showAnalyzer(with text: String) {
        let analyzerView = ShareNotesAnalyzerView(sharedText: text) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        showHostedView(analyzerView)
    }

    private func showHostedView<V: View>(_ rootView: V) {
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    private func removeHostedView() {
        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
}
