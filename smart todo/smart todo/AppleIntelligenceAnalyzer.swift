//
//  AppleIntelligenceAnalyzer.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 7/2/2026.
//

import Foundation
import CoreData

#if canImport(FoundationModels)
import FoundationModels

/// Response schema for task categorization using Apple Intelligence
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct TaskCategoryResponse {
    /// The detected category for the task
    @Guide(description: "The location category that best matches this task. Must be one of: pharmacy, fuel_station, supermarket, grocery, restaurant, bank, post_office, hardware, electronics, clothing, or none if no category matches.")
    var category: String

    /// Confidence level of the categorization
    @Guide(description: "Confidence level from 0.0 to 1.0 indicating how confident the model is about this categorization.")
    var confidence: Double
}

/// Analyzes tasks using Apple Intelligence (on-device LLM)
@available(iOS 26.0, macOS 26.0, *)
@MainActor
class AppleIntelligenceAnalyzer {

    /// Shared instance for convenience
    static let shared = AppleIntelligenceAnalyzer()

    /// The language model session
    private var session: LanguageModelSession?

    /// Cached availability status
    private static var _isAvailable: Bool?

    /// Check if Apple Intelligence is available on this device
    @MainActor
    static var isAvailable: Bool {
        if let cached = _isAvailable {
            return cached
        }
        // Try to create a session to check availability
        let available = (try? LanguageModelSession()) != nil
        _isAvailable = available
        return available
    }

    /// Initialize the analyzer
    private init() {
        setupSession()
    }

    /// Set up the language model session
    private func setupSession() {
        session = try? LanguageModelSession()
        if session == nil {
            print("Failed to create language model session")
        }
    }

    /// Analyze a task title and return the detected category
    /// - Parameter title: The task title to analyze
    /// - Returns: The detected LocationCategory, or nil if no match
    func analyzeTask(title: String) async -> LocationCategory? {
        // Validate input
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return nil
        }

        guard let session = session else {
            print("No language model session available, falling back to keyword matching")
            return TaskCategoryAnalyzer.primaryCategory(for: title)
        }

        let prompt = """
        Analyze this task and determine which location category it belongs to.

        Task: "\(trimmedTitle)"

        Available categories:
        - pharmacy: Tasks related to medicines, prescriptions, health supplies
        - fuel_station: Tasks related to refueling vehicles (petrol, gas, diesel)
        - supermarket: Tasks related to grocery shopping, food supplies
        - grocery: Tasks related to specific food items (milk, bread, eggs, etc.)
        - restaurant: Tasks related to dining out, takeaway food
        - bank: Tasks related to banking, cash, financial transactions
        - post_office: Tasks related to mail, parcels, shipping
        - hardware: Tasks related to tools, home improvement, DIY
        - electronics: Tasks related to electronic devices, gadgets
        - clothing: Tasks related to clothes, shoes, fashion
        - none: Task doesn't match any location category

        Respond with the most appropriate category.
        """

        do {
            // Check for task cancellation before making the API call
            try Task.checkCancellation()

            let response = try await session.respond(
                to: prompt,
                generating: TaskCategoryResponse.self
            )

            // Check for cancellation after API call
            try Task.checkCancellation()

            let result = response.content

            // Validate the response
            guard !result.category.isEmpty else {
                print("Empty category response, falling back to keyword matching")
                return TaskCategoryAnalyzer.primaryCategory(for: title)
            }

            // Only accept high-confidence predictions
            guard result.confidence >= 0.6 else {
                print("Low confidence (\(result.confidence)), falling back to keyword matching")
                return TaskCategoryAnalyzer.primaryCategory(for: title)
            }

            // Map response to LocationCategory
            if result.category == "none" {
                return nil
            }

            return LocationCategory(rawValue: result.category)

        } catch is CancellationError {
            // Task was cancelled, just return nil without fallback
            print("Apple Intelligence analysis was cancelled")
            return nil
        } catch {
            print("Apple Intelligence analysis failed: \(error)")
            // Fall back to keyword matching
            return TaskCategoryAnalyzer.primaryCategory(for: title)
        }
    }

    /// Analyze a task and return all matching categories with confidence scores
    /// - Parameter title: The task title to analyze
    /// - Returns: Array of tuples containing category and confidence
    func analyzeTaskWithConfidence(title: String) async -> [(category: LocationCategory, confidence: Double)] {
        // Validate input
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return []
        }

        guard session != nil else {
            // Fall back to keyword matching (assign synthetic confidence based on keyword match score)
            let categories = TaskCategoryAnalyzer.analyzeTask(title: trimmedTitle)
            return categories.enumerated().map { index, category in
                (category, 0.8 - Double(index) * 0.1) // Decreasing confidence for secondary matches
            }
        }

        do {
            // Check for cancellation
            try Task.checkCancellation()

            // For multi-category analysis, get the primary category and supplement with keyword matching
            if let primaryCategory = await analyzeTask(title: trimmedTitle) {
                var results: [(LocationCategory, Double)] = [(primaryCategory, 0.9)]

                // Add secondary matches from keyword analysis
                let keywordMatches = TaskCategoryAnalyzer.analyzeTask(title: trimmedTitle)
                for category in keywordMatches where category != primaryCategory {
                    results.append((category, 0.5))
                }

                return results
            }

            // If no AI match, try keyword matching
            let categories = TaskCategoryAnalyzer.analyzeTask(title: trimmedTitle)
            return categories.enumerated().map { index, category in
                (category, 0.7 - Double(index) * 0.1)
            }

        } catch is CancellationError {
            print("Analysis with confidence was cancelled")
            return []
        } catch {
            print("Analysis with confidence failed: \(error)")
            // Fall back to keyword matching
            let categories = TaskCategoryAnalyzer.analyzeTask(title: trimmedTitle)
            return categories.enumerated().map { index, category in
                (category, 0.7 - Double(index) * 0.1)
            }
        }
    }
}

#endif

// MARK: - Unified Smart Task Analyzer

/// Unified analyzer that uses Apple Intelligence when available, falls back to keywords
class SmartTaskAnalyzer {

    /// Shared instance
    static let shared = SmartTaskAnalyzer()

    private init() {}

    /// Check if Apple Intelligence is available
    @MainActor
    var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return AppleIntelligenceAnalyzer.isAvailable
        }
        #endif
        return false
    }

    /// Analyze a task title and return the detected category
    /// Uses Apple Intelligence if available, otherwise falls back to keyword matching
    /// - Parameter title: The task title to analyze
    /// - Returns: The detected LocationCategory, or nil if no match
    @MainActor
    func analyzeTask(title: String) async -> LocationCategory? {
        // Validate input
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return nil
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AppleIntelligenceAnalyzer.isAvailable {
            do {
                try Task.checkCancellation()
                return await AppleIntelligenceAnalyzer.shared.analyzeTask(title: trimmedTitle)
            } catch is CancellationError {
                return nil
            } catch {
                print("SmartTaskAnalyzer error: \(error)")
                // Fall through to keyword matching
            }
        }
        #endif

        // Fall back to keyword matching
        return TaskCategoryAnalyzer.primaryCategory(for: trimmedTitle)
    }

    /// Synchronous analysis using keyword matching only
    /// Use this when you need immediate results without async/await
    func analyzeTaskSync(title: String) -> LocationCategory? {
        return TaskCategoryAnalyzer.primaryCategory(for: title)
    }

    /// Get all matching categories for a task
    @MainActor
    func analyzeTaskAllCategories(title: String) async -> [LocationCategory] {
        // Validate input
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return []
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AppleIntelligenceAnalyzer.isAvailable {
            do {
                try Task.checkCancellation()
                let results = await AppleIntelligenceAnalyzer.shared.analyzeTaskWithConfidence(title: trimmedTitle)
                return results.map { $0.category }
            } catch is CancellationError {
                return []
            } catch {
                print("SmartTaskAnalyzer analyzeAllCategories error: \(error)")
                // Fall through to keyword matching
            }
        }
        #endif

        // Fall back to keyword matching
        return TaskCategoryAnalyzer.analyzeTask(title: trimmedTitle)
    }

    /// Find matching POIs for detected categories
    /// - Parameters:
    ///   - categories: The location categories to match
    ///   - context: The Core Data managed object context
    /// - Returns: Array of matching PointOfInterest objects
    func findMatchingPOIs(for categories: [LocationCategory], in context: NSManagedObjectContext) -> [PointOfInterest] {
        return TaskCategoryAnalyzer.findMatchingPOIs(for: categories, in: context)
    }
}
