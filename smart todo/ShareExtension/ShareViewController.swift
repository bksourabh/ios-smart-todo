//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Sourabh Mazumder on 8/3/2026.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    private let appGroupID = "group.com.helpingthoughtgames.smart-todo"
    private let sharedKey = "SharedNotesText"

    override func isContentValid() -> Bool {
        // Valid as long as there's some text
        let text = contentText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !text.isEmpty
    }

    override func didSelectPost() {
        guard let text = contentText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        // Also check for any text attachments from the share sheet
        var fullText = text

        if let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] {
            let group = DispatchGroup()

            for item in extensionItems {
                guard let attachments = item.attachments else { continue }
                for provider in attachments {
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        group.enter()
                        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, _) in
                            if let sharedText = data as? String, sharedText != text {
                                fullText = fullText + "\n" + sharedText
                            }
                            group.leave()
                        }
                    }
                }
            }

            group.notify(queue: .main) { [weak self] in
                self?.saveAndOpen(fullText)
            }
        } else {
            saveAndOpen(fullText)
        }
    }

    private func saveAndOpen(_ text: String) {
        // Save to shared UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.set(text, forKey: sharedKey)
            sharedDefaults.synchronize()
        }

        // Open main app via URL scheme
        if let url = URL(string: "smarttodo://import-notes") {
            openURL(url)
        }

        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // Extension-safe way to open a URL
    @objc private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = r.next
        }
        // Fallback: use the extensionContext to open the URL
        extensionContext?.open(url, completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}
