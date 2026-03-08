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

/// Response schema for grouping notes items by location
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct NotesGroupingResponse {
    /// JSON array of task groups. Each group has: "groupTitle" (string, a short name describing where these tasks are done, e.g. "Supermarket Run", "Pharmacy Visit"), "locationCategory" (string, one of: pharmacy, fuel_station, supermarket, grocery, restaurant, bank, post_office, hardware, electronics, clothing, or none), and "items" (array of strings, the individual task items in this group).
    @Guide(description: "A JSON array of task groups. Each element is a JSON object with keys: groupTitle (string), locationCategory (string from the allowed categories or none), items (array of strings). Group related items by where they can be completed. Example: [{\"groupTitle\":\"Grocery Shopping\",\"locationCategory\":\"supermarket\",\"items\":[\"milk\",\"tomatoes\"]},{\"groupTitle\":\"Pharmacy Visit\",\"locationCategory\":\"pharmacy\",\"items\":[\"medicines\"]}]")
    var groupsJSON: String
}

/// Response schema for actionable task detection
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct ActionableTaskResponse {
    /// Whether the text represents an actionable task
    @Guide(description: "True if the text contains an action verb and represents something that can be done or completed (e.g., 'buy groceries', 'call mom', 'pick up package'). False if it's a question, observation, note, or non-actionable text (e.g., 'how is the weather?', 'meeting notes', 'birthday ideas').")
    var isActionable: Bool

    /// Confidence level of the detection
    @Guide(description: "Confidence level from 0.0 to 1.0 indicating how confident the model is about this classification.")
    var confidence: Double

    /// The detected action verb if actionable
    @Guide(description: "The main action verb detected in the text (e.g., 'buy', 'call', 'pick up', 'send'). Empty string if not actionable.")
    var actionVerb: String
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
        // Check if language model session can be created
        // LanguageModelSession is available if the device supports Apple Intelligence
        _isAvailable = true
        return true
    }

    /// Initialize the analyzer
    private init() {
        setupSession()
    }

    /// Set up the language model session
    private func setupSession() {
        session = LanguageModelSession()
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

    /// Check if a text represents an actionable task (contains action verb)
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text is an actionable task, false otherwise
    func isActionableTask(text: String) async -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return false
        }

        guard let session = session else {
            // Fall back to keyword-based detection
            return Self.isActionableTaskKeywordBased(text: trimmedText)
        }

        let prompt = """
        Analyze this text and determine if it represents an actionable task that someone needs to do.

        Text: "\(trimmedText)"

        An actionable task:
        - Contains an action verb (buy, get, pick up, call, send, schedule, book, make, prepare, clean, fix, etc.)
        - Represents something that can be completed or done
        - Examples: "buy groceries", "call mom", "pick up dry cleaning", "send email to John"

        NOT an actionable task:
        - Questions (how, what, why, when, where, who, is, are, do, does, can, will, should)
        - Observations or notes without actions
        - Ideas or reminders without specific actions
        - Examples: "how is the weather?", "meeting notes", "birthday ideas", "what time is it?"

        Determine if this is an actionable task.
        """

        do {
            try Task.checkCancellation()

            let response = try await session.respond(
                to: prompt,
                generating: ActionableTaskResponse.self
            )

            try Task.checkCancellation()

            let result = response.content

            // Only accept high-confidence predictions
            guard result.confidence >= 0.6 else {
                return Self.isActionableTaskKeywordBased(text: trimmedText)
            }

            return result.isActionable

        } catch is CancellationError {
            print("Actionable task analysis was cancelled")
            return false
        } catch {
            print("Actionable task analysis failed: \(error)")
            return Self.isActionableTaskKeywordBased(text: trimmedText)
        }
    }

    /// Group notes items by location category using Apple Intelligence
    /// - Parameter items: Array of individual task/item strings parsed from notes
    /// - Returns: Array of grouped tasks with location categories
    func groupNotesItems(_ items: [String]) async -> [NotesTaskGroup] {
        guard !items.isEmpty else { return [] }

        guard let session = session else {
            return NotesTaskGroup.groupByKeywords(items)
        }

        let itemsList = items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let prompt = """
        You have a list of items from a user's notes. Group these items by the location where they can be completed or purchased.

        Items:
        \(itemsList)

        Rules:
        - Group items that can be bought/done at the same type of location together
        - Each group needs a short, friendly title (e.g. "Grocery Shopping", "Pharmacy Visit")
        - Assign a locationCategory to each group: pharmacy, fuel_station, supermarket, grocery, restaurant, bank, post_office, hardware, electronics, clothing, or none
        - Items like milk, tomatoes, bread, eggs go to supermarket or grocery
        - Items like medicines, prescriptions go to pharmacy
        - If an item doesn't fit any category, put it in a group with locationCategory "none"
        - Keep the original item text as-is

        Return the grouping as a JSON array.
        """

        do {
            try Task.checkCancellation()

            let response = try await session.respond(
                to: prompt,
                generating: NotesGroupingResponse.self
            )

            try Task.checkCancellation()

            let jsonString = response.content.groupsJSON
            if let data = jsonString.data(using: .utf8),
               let groups = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return groups.compactMap { dict -> NotesTaskGroup? in
                    guard let title = dict["groupTitle"] as? String,
                          let categoryStr = dict["locationCategory"] as? String,
                          let items = dict["items"] as? [String] else { return nil }
                    let category = LocationCategory(rawValue: categoryStr)
                    return NotesTaskGroup(groupTitle: title, locationCategory: category, items: items)
                }
            }

            return NotesTaskGroup.groupByKeywords(items)
        } catch is CancellationError {
            return []
        } catch {
            print("Apple Intelligence notes grouping failed: \(error)")
            return NotesTaskGroup.groupByKeywords(items)
        }
    }

    /// Keyword-based fallback for actionable task detection
    private static func isActionableTaskKeywordBased(text: String) -> Bool {
        let lowercasedText = text.lowercased()

        // Check if it's a question (not actionable)
        let questionPatterns = ["how ", "what ", "why ", "when ", "where ", "who ", "which ",
                                 "is ", "are ", "do ", "does ", "can ", "will ", "should ",
                                 "could ", "would ", "have ", "has ", "?"]
        for pattern in questionPatterns {
            if lowercasedText.hasPrefix(pattern) || lowercasedText.contains("?") {
                return false
            }
        }

        // Check for action verbs (actionable)
        let actionVerbs = ["buy", "get", "pick up", "pickup", "call", "send", "email", "text",
                           "schedule", "book", "make", "prepare", "cook", "clean", "fix",
                           "repair", "pay", "submit", "complete", "finish", "start", "begin",
                           "order", "return", "exchange", "cancel", "renew", "update",
                           "check", "review", "read", "write", "sign", "fill", "apply",
                           "register", "enroll", "attend", "visit", "meet", "drop off",
                           "drop", "deliver", "ship", "mail", "post", "take", "bring",
                           "collect", "gather", "organize", "sort", "file", "print",
                           "scan", "copy", "download", "upload", "install", "setup",
                           "configure", "backup", "charge", "refill", "replace", "wash",
                           "iron", "fold", "pack", "unpack", "move", "arrange", "decorate",
                           "plan", "research", "find", "look for", "search", "contact",
                           "remind", "notify", "tell", "ask", "confirm", "verify", "test"]

        for verb in actionVerbs {
            if lowercasedText.contains(verb) {
                return true
            }
        }

        // Default: assume it's actionable if it doesn't look like a question
        // and has reasonable length (likely a task description)
        return lowercasedText.count >= 3 && !lowercasedText.contains("?")
    }
}

#endif

// MARK: - Notes Task Group Model

/// Represents a group of tasks that can be completed at the same type of location
struct NotesTaskGroup: Identifiable {
    let id = UUID()
    var groupTitle: String
    var locationCategory: LocationCategory?
    var items: [String]

    /// Keyword-based fallback for grouping items by location
    static func groupByKeywords(_ items: [String]) -> [NotesTaskGroup] {
        var categoryItems: [LocationCategory: [String]] = [:]
        var uncategorized: [String] = []

        for item in items {
            if let category = TaskCategoryAnalyzer.primaryCategory(for: item) {
                categoryItems[category, default: []].append(item)
            } else {
                uncategorized.append(item)
            }
        }

        var groups: [NotesTaskGroup] = []

        // Merge grocery and supermarket into one group
        let groceryItems = (categoryItems[.grocery] ?? []) + (categoryItems[.supermarket] ?? [])
        if !groceryItems.isEmpty {
            groups.append(NotesTaskGroup(
                groupTitle: "Grocery Shopping",
                locationCategory: .supermarket,
                items: groceryItems
            ))
            categoryItems.removeValue(forKey: .grocery)
            categoryItems.removeValue(forKey: .supermarket)
        }

        for (category, items) in categoryItems {
            groups.append(NotesTaskGroup(
                groupTitle: "\(category.singularDisplayName) Visit",
                locationCategory: category,
                items: items
            ))
        }

        if !uncategorized.isEmpty {
            groups.append(NotesTaskGroup(
                groupTitle: "Other Tasks",
                locationCategory: nil,
                items: uncategorized
            ))
        }

        return groups
    }
}

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

    /// Check if text represents an actionable task
    /// Uses Apple Intelligence if available, otherwise falls back to keyword matching
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text is an actionable task, false otherwise
    @MainActor
    func isActionableTask(text: String) async -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return false
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AppleIntelligenceAnalyzer.isAvailable {
            do {
                try Task.checkCancellation()
                return await AppleIntelligenceAnalyzer.shared.isActionableTask(text: trimmedText)
            } catch is CancellationError {
                return false
            } catch {
                print("SmartTaskAnalyzer isActionableTask error: \(error)")
                // Fall through to keyword matching
            }
        }
        #endif

        // Fall back to keyword-based detection
        return isActionableTaskKeywordBased(text: trimmedText)
    }

    /// Keyword-based fallback for actionable task detection (synchronous)
    private func isActionableTaskKeywordBased(text: String) -> Bool {
        let lowercasedText = text.lowercased()

        // Check if it's a question (not actionable)
        let questionPatterns = ["how ", "what ", "why ", "when ", "where ", "who ", "which ",
                                 "is ", "are ", "do ", "does ", "can ", "will ", "should ",
                                 "could ", "would ", "have ", "has ", "?"]
        for pattern in questionPatterns {
            if lowercasedText.hasPrefix(pattern) || lowercasedText.contains("?") {
                return false
            }
        }

        // Check for action verbs (actionable)
        let actionVerbs = ["buy", "get", "pick up", "pickup", "call", "send", "email", "text",
                           "schedule", "book", "make", "prepare", "cook", "clean", "fix",
                           "repair", "pay", "submit", "complete", "finish", "start", "begin",
                           "order", "return", "exchange", "cancel", "renew", "update",
                           "check", "review", "read", "write", "sign", "fill", "apply",
                           "register", "enroll", "attend", "visit", "meet", "drop off",
                           "drop", "deliver", "ship", "mail", "post", "take", "bring",
                           "collect", "gather", "organize", "sort", "file", "print",
                           "scan", "copy", "download", "upload", "install", "setup",
                           "configure", "backup", "charge", "refill", "replace", "wash",
                           "iron", "fold", "pack", "unpack", "move", "arrange", "decorate",
                           "plan", "research", "find", "look for", "search", "contact",
                           "remind", "notify", "tell", "ask", "confirm", "verify", "test"]

        for verb in actionVerbs {
            if lowercasedText.contains(verb) {
                return true
            }
        }

        // Default: assume it's actionable if it doesn't look like a question
        // and has reasonable length (likely a task description)
        return lowercasedText.count >= 3 && !lowercasedText.contains("?")
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

    // MARK: - Notes Grouping

    /// Group notes items by location using Apple Intelligence or keyword fallback
    /// - Parameter items: Array of individual task/item strings from notes
    /// - Returns: Array of NotesTaskGroup with items grouped by location
    @MainActor
    func groupNotesItems(_ items: [String]) async -> [NotesTaskGroup] {
        guard !items.isEmpty else { return [] }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AppleIntelligenceAnalyzer.isAvailable {
            do {
                try Task.checkCancellation()
                return await AppleIntelligenceAnalyzer.shared.groupNotesItems(items)
            } catch is CancellationError {
                return []
            } catch {
                print("SmartTaskAnalyzer groupNotesItems error: \(error)")
            }
        }
        #endif

        return NotesTaskGroup.groupByKeywords(items)
    }

    // MARK: - Batch Analysis for Import

    /// Analyze multiple items for import, processing in batches
    /// Filters out non-actionable items (questions, observations) and only includes actionable tasks
    /// - Parameters:
    ///   - items: The items to analyze
    ///   - context: The Core Data managed object context for POI matching
    /// - Returns: Array of analyzed ImportableItem objects with categories, POIs, and suggested notification types
    @MainActor
    func analyzeItemsForImport(_ items: [ImportableItem], in context: NSManagedObjectContext) async -> [ImportableItem] {
        var analyzedItems: [ImportableItem] = []

        // Process items sequentially to avoid NSManagedObjectContext threading issues
        for item in items {
            // First check if the item is an actionable task (has action verb, not a question)
            let analysisText = item.analysisText
            let isActionable = await isActionableTask(text: analysisText)

            // Skip non-actionable items (questions like "how is the weather?")
            guard isActionable else {
                print("Skipping non-actionable item: \(item.title)")
                continue
            }

            let analyzedItem = await analyzeImportItem(item, in: context)
            analyzedItems.append(analyzedItem)
        }

        return analyzedItems
    }

    /// Analyze a single import item
    @MainActor
    private func analyzeImportItem(_ item: ImportableItem, in context: NSManagedObjectContext) async -> ImportableItem {
        var analyzedItem = item

        // Analyze the combined title + notes for categories
        let analysisText = item.analysisText
        let categories = await analyzeTaskAllCategories(title: analysisText)
        analyzedItem.detectedCategories = categories

        // Find matching POIs for detected categories
        if !categories.isEmpty {
            let matchingPOIs = findMatchingPOIs(for: categories, in: context)
            analyzedItem.matchingPOIs = matchingPOIs
        }

        // Determine suggested notification type
        analyzedItem.suggestedNotificationType = determineSuggestedNotificationType(for: analyzedItem)

        return analyzedItem
    }

    /// Determine the suggested notification type based on item properties
    private func determineSuggestedNotificationType(for item: ImportableItem) -> SuggestedNotificationType {
        // Priority 1: Has due date/time → time-based notification
        if item.dueDate != nil {
            return .time
        }

        // Priority 2: AI detects category + POIs exist → smart notification
        if !item.detectedCategories.isEmpty && !item.matchingPOIs.isEmpty {
            return .smart
        }

        // Priority 3: Has detected categories but no matching POIs → still suggest smart
        // (user might add POIs later)
        if !item.detectedCategories.isEmpty {
            return .smart
        }

        // Priority 4: No triggers detected → manual
        return .manual
    }
}
