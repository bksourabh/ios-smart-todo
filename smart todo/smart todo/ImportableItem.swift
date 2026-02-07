//
//  ImportableItem.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 7/2/2026.
//

import Foundation
import EventKit

/// Source type for imported items
enum ImportSourceType: String, CaseIterable {
    case calendar = "calendar"
    case reminder = "reminder"

    var displayName: String {
        switch self {
        case .calendar: return "Calendar"
        case .reminder: return "Reminder"
        }
    }

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .reminder: return "list.bullet"
        }
    }

    var color: String {
        switch self {
        case .calendar: return "red"
        case .reminder: return "blue"
        }
    }
}

/// Suggested notification type for imported items
enum SuggestedNotificationType: String, CaseIterable {
    case time = "time"
    case smart = "smart"
    case location = "location"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .time: return "Time-Based"
        case .smart: return "Smart"
        case .location: return "Location"
        case .manual: return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .time: return "clock.fill"
        case .smart: return "sparkles"
        case .location: return "location.fill"
        case .manual: return "hand.tap.fill"
        }
    }

    var description: String {
        switch self {
        case .time: return "Remind before due date/time"
        case .smart: return "Notify at matching locations"
        case .location: return "Notify at a specific location"
        case .manual: return "No automatic notification"
        }
    }
}

/// Unified model abstracting EKEvent and EKReminder for import
struct ImportableItem: Identifiable, Equatable {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    let startDate: Date?
    let endDate: Date?
    let sourceType: ImportSourceType
    let originalIdentifier: String

    // Analysis results (populated after AI analysis)
    var detectedCategories: [LocationCategory] = []
    var matchingPOIs: [PointOfInterest] = []
    var suggestedNotificationType: SuggestedNotificationType = .manual

    // Selection state
    var isSelected: Bool = true
    var isAlreadyImported: Bool = false

    // MARK: - Initializers

    /// Initialize from an EKEvent
    init(from event: EKEvent, isAlreadyImported: Bool = false) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Untitled Event"
        self.notes = event.notes
        self.dueDate = event.endDate
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.sourceType = .calendar
        self.originalIdentifier = event.eventIdentifier ?? EventKitManager.shared.generateFallbackIdentifier(
            title: event.title ?? "",
            date: event.startDate
        )
        self.isAlreadyImported = isAlreadyImported
        self.isSelected = !isAlreadyImported
    }

    /// Initialize from an EKReminder
    init(from reminder: EKReminder, isAlreadyImported: Bool = false) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? "Untitled Reminder"
        self.notes = reminder.notes

        // Get due date from reminder's due date components
        if let dueDateComponents = reminder.dueDateComponents {
            self.dueDate = Calendar.current.date(from: dueDateComponents)
        } else {
            self.dueDate = nil
        }

        self.startDate = nil
        self.endDate = self.dueDate
        self.sourceType = .reminder
        self.originalIdentifier = reminder.calendarItemIdentifier
        self.isAlreadyImported = isAlreadyImported
        self.isSelected = !isAlreadyImported
    }

    /// Initialize with all properties (for testing or manual creation)
    init(
        id: String,
        title: String,
        notes: String?,
        dueDate: Date?,
        startDate: Date? = nil,
        endDate: Date? = nil,
        sourceType: ImportSourceType,
        originalIdentifier: String,
        detectedCategories: [LocationCategory] = [],
        matchingPOIs: [PointOfInterest] = [],
        suggestedNotificationType: SuggestedNotificationType = .manual,
        isSelected: Bool = true,
        isAlreadyImported: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.startDate = startDate
        self.endDate = endDate
        self.sourceType = sourceType
        self.originalIdentifier = originalIdentifier
        self.detectedCategories = detectedCategories
        self.matchingPOIs = matchingPOIs
        self.suggestedNotificationType = suggestedNotificationType
        self.isSelected = isSelected
        self.isAlreadyImported = isAlreadyImported
    }

    // MARK: - Equatable

    static func == (lhs: ImportableItem, rhs: ImportableItem) -> Bool {
        return lhs.id == rhs.id
    }

    // MARK: - Computed Properties

    /// Combined text for analysis (title + notes)
    var analysisText: String {
        if let notes = notes, !notes.isEmpty {
            return "\(title) \(notes)"
        }
        return title
    }

    /// Display date text
    var dateDisplayText: String? {
        guard let date = dueDate else { return nil }

        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }

        return formatter.string(from: date)
    }

    /// Primary detected category (if any)
    var primaryCategory: LocationCategory? {
        return detectedCategories.first
    }

    /// Number of matching POIs
    var matchingPOICount: Int {
        return matchingPOIs.count
    }

    /// Whether this item has location context
    var hasLocationContext: Bool {
        return !detectedCategories.isEmpty || !matchingPOIs.isEmpty
    }

    /// Suggested notification reason text
    var notificationReasonText: String {
        switch suggestedNotificationType {
        case .time:
            return "Has a due date"
        case .smart:
            if let category = primaryCategory {
                return "Matches \(category.displayName)"
            }
            return "Matches saved locations"
        case .location:
            return "Location detected"
        case .manual:
            return "No automatic triggers"
        }
    }
}

// MARK: - Array Extension for Grouping

extension Array where Element == ImportableItem {
    /// Group items by source type
    var groupedBySource: [ImportSourceType: [ImportableItem]] {
        return Dictionary(grouping: self) { $0.sourceType }
    }

    /// Filter to only selected items
    var selectedItems: [ImportableItem] {
        return filter { $0.isSelected }
    }

    /// Filter to items that haven't been imported yet
    var newItems: [ImportableItem] {
        return filter { !$0.isAlreadyImported }
    }

    /// Count of calendar items
    var calendarItemCount: Int {
        return filter { $0.sourceType == .calendar }.count
    }

    /// Count of reminder items
    var reminderItemCount: Int {
        return filter { $0.sourceType == .reminder }.count
    }
}
