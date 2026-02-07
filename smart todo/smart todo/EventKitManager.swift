//
//  EventKitManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 7/2/2026.
//

import Foundation
import EventKit
import Combine

/// Singleton service for EventKit permissions and data fetching
final class EventKitManager: ObservableObject {
    static let shared = EventKitManager()

    private let eventStore = EKEventStore()

    // MARK: - Published Properties

    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined

    // MARK: - UserDefaults Keys for Duplicate Tracking

    private let importedCalendarEventsKey = "importedCalendarEventIdentifiers"
    private let importedRemindersKey = "importedReminderIdentifiers"

    // MARK: - Computed Properties

    var isCalendarAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return calendarAuthorizationStatus == .fullAccess
        } else {
            return calendarAuthorizationStatus == .authorized
        }
    }

    var isReminderAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return reminderAuthorizationStatus == .fullAccess
        } else {
            return reminderAuthorizationStatus == .authorized
        }
    }

    // MARK: - Initialization

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization Status

    func checkAuthorizationStatus() {
        if #available(iOS 17.0, *) {
            calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
            reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        } else {
            calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
            reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        }
    }

    // MARK: - Permission Requests

    /// Request calendar access
    /// - Returns: True if access was granted
    func requestCalendarAccess() async -> Bool {
        do {
            var granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }

            await MainActor.run {
                checkAuthorizationStatus()
            }

            return granted
        } catch {
            print("Error requesting calendar access: \(error)")
            return false
        }
    }

    /// Request reminder access
    /// - Returns: True if access was granted
    func requestReminderAccess() async -> Bool {
        do {
            var granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToReminders()
            } else {
                granted = try await eventStore.requestAccess(to: .reminder)
            }

            await MainActor.run {
                checkAuthorizationStatus()
            }

            return granted
        } catch {
            print("Error requesting reminder access: \(error)")
            return false
        }
    }

    // MARK: - Data Fetching

    /// Fetch calendar events within a date range
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range
    /// - Returns: Array of EKEvent objects
    func fetchCalendarEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard isCalendarAuthorized else {
            print("Calendar not authorized")
            return []
        }

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        // Filter out all-day events that have passed and events without titles
        let filteredEvents = events.filter { event in
            guard let title = event.title, !title.isEmpty else { return false }
            // Include future events or events happening today
            if event.isAllDay {
                return event.startDate >= Calendar.current.startOfDay(for: Date())
            }
            return event.endDate >= Date()
        }

        return filteredEvents
    }

    /// Fetch all incomplete reminders
    /// - Returns: Array of EKReminder objects
    func fetchReminders() async -> [EKReminder] {
        guard isReminderAuthorized else {
            print("Reminders not authorized")
            return []
        }

        return await withCheckedContinuation { continuation in
            let calendars = eventStore.calendars(for: .reminder)
            let predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: calendars
            )

            eventStore.fetchReminders(matching: predicate) { reminders in
                // Filter reminders with titles
                let filteredReminders = (reminders ?? []).filter { reminder in
                    guard let title = reminder.title, !title.isEmpty else { return false }
                    return true
                }
                continuation.resume(returning: filteredReminders)
            }
        }
    }

    // MARK: - Duplicate Tracking

    /// Get the set of already imported calendar event identifiers
    func getImportedCalendarEventIdentifiers() -> Set<String> {
        let identifiers = UserDefaults.standard.stringArray(forKey: importedCalendarEventsKey) ?? []
        return Set(identifiers)
    }

    /// Get the set of already imported reminder identifiers
    func getImportedReminderIdentifiers() -> Set<String> {
        let identifiers = UserDefaults.standard.stringArray(forKey: importedRemindersKey) ?? []
        return Set(identifiers)
    }

    /// Mark a calendar event as imported
    func markCalendarEventAsImported(_ identifier: String) {
        var identifiers = getImportedCalendarEventIdentifiers()
        identifiers.insert(identifier)
        UserDefaults.standard.set(Array(identifiers), forKey: importedCalendarEventsKey)
    }

    /// Mark a reminder as imported
    func markReminderAsImported(_ identifier: String) {
        var identifiers = getImportedReminderIdentifiers()
        identifiers.insert(identifier)
        UserDefaults.standard.set(Array(identifiers), forKey: importedRemindersKey)
    }

    /// Mark multiple calendar events as imported
    func markCalendarEventsAsImported(_ identifiers: [String]) {
        var currentIdentifiers = getImportedCalendarEventIdentifiers()
        identifiers.forEach { currentIdentifiers.insert($0) }
        UserDefaults.standard.set(Array(currentIdentifiers), forKey: importedCalendarEventsKey)
    }

    /// Mark multiple reminders as imported
    func markRemindersAsImported(_ identifiers: [String]) {
        var currentIdentifiers = getImportedReminderIdentifiers()
        identifiers.forEach { currentIdentifiers.insert($0) }
        UserDefaults.standard.set(Array(currentIdentifiers), forKey: importedRemindersKey)
    }

    /// Check if a calendar event has been imported
    func isCalendarEventImported(_ identifier: String) -> Bool {
        return getImportedCalendarEventIdentifiers().contains(identifier)
    }

    /// Check if a reminder has been imported
    func isReminderImported(_ identifier: String) -> Bool {
        return getImportedReminderIdentifiers().contains(identifier)
    }

    /// Generate a fallback identifier for items without stable identifiers
    /// Uses a hash of title + date
    func generateFallbackIdentifier(title: String, date: Date?) -> String {
        let dateString = date?.timeIntervalSince1970.description ?? "nodate"
        let combined = "\(title.lowercased())-\(dateString)"
        return String(combined.hashValue)
    }

    /// Clear all imported identifiers (for testing/reset)
    func clearImportedIdentifiers() {
        UserDefaults.standard.removeObject(forKey: importedCalendarEventsKey)
        UserDefaults.standard.removeObject(forKey: importedRemindersKey)
    }
}
