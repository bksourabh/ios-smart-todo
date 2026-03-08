//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Sourabh Mazumder on 8/3/2026.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private var hasProcessed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasProcessed else { return }
        hasProcessed = true
        extractText()
    }

    private func extractText() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showAnalyzer(with: "")
            return
        }

        var collectedTexts: [String] = []
        let group = DispatchGroup()

        for item in extensionItems {
            // Notes shares via attributedContentText
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
                            collectedTexts.append(text)
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                        if let url = data as? URL {
                            collectedTexts.append(url.absoluteString)
                        } else if let text = data as? String {
                            collectedTexts.append(text)
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            let unique = self?.deduplicateTexts(collectedTexts) ?? []
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

    private func showAnalyzer(with text: String) {
        let analyzerView = ShareNotesAnalyzerView(sharedText: text) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }

        let hostingController = UIHostingController(rootView: analyzerView)
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
}
