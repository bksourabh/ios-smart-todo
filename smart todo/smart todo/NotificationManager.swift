//
//  NotificationManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import Foundation
import UserNotifications
import CoreData
import Combine
import UIKit
import CoreLocation

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var activeLocationTasks: [String: String] = [:] // taskId: taskTitle

    private var managedObjectContext: NSManagedObjectContext?

    private init() {
        checkAuthorizationStatus()

        // Set up as region delegate for LocationManager
        LocationManager.shared.regionDelegate = self
    }

    func setManagedObjectContext(_ context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                checkAuthorizationStatus()
            }
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    func scheduleNotification(for task: TodoTask) {
        print("scheduleNotification called for task: \(task.title ?? "unknown")")

        // Only schedule if notifications are authorized
        guard authorizationStatus == .authorized else {
            print("Notification authorization not granted. Status: \(authorizationStatus.rawValue)")
            return
        }

        // Only schedule if task is not completed
        guard !task.isCompleted else {
            print("Task is completed, cancelling notification")
            cancelNotification(for: task)
            return
        }

        // Cancel existing notification for this task
        cancelNotification(for: task)

        let notificationType = task.notificationType ?? "smart"
        print("Notification type: \(notificationType)")

        switch notificationType {
        case "location":
            scheduleLocationNotification(for: task)
        case "smart":
            // Smart notifications are scheduled separately with matching POIs
            // This is called when re-scheduling existing smart tasks
            if let context = managedObjectContext,
               let categoryRawValue = task.smartLocationCategory,
               let category = LocationCategory(rawValue: categoryRawValue) {
                let matchingPOIs = TaskCategoryAnalyzer.findMatchingPOIs(for: [category], in: context)
                if !matchingPOIs.isEmpty {
                    scheduleSmartNotifications(for: task, matchingPOIs: matchingPOIs)
                }
            }
        default:
            scheduleTimeNotification(for: task)
        }
    }

    private func scheduleTimeNotification(for task: TodoTask) {
        // Check if notification is enabled (notificationMinutes > 0)
        let notificationMinutes = Int(task.notificationMinutes)
        guard notificationMinutes > 0 else {
            return
        }

        var dueDate: Date?
        var notificationTitle: String = ""

        // Determine due date based on task type
        if let dateType = task.dateType {
            if dateType == "dueDate", let taskDueDate = task.dueDate {
                dueDate = taskDueDate
                notificationTitle = task.title ?? "Task due"
            } else if dateType == "toBeDoneIn", let endDate = task.endDate {
                dueDate = endDate
                notificationTitle = task.title ?? "Task due"
            }
        }

        guard let taskDueDate = dueDate else { return }

        // Calculate notification date (x minutes before due date)
        let notificationDate = taskDueDate.addingTimeInterval(-Double(notificationMinutes) * 60)

        // Validate notification is not in the past
        guard notificationDate >= Date() else {
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "\(notificationTitle) is due in \(notificationMinutes) minute\(notificationMinutes == 1 ? "" : "s")"
        content.sound = .default
        content.badge = 1

        // Create trigger for the notification date
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // Create request with task ID as identifier
        let identifier = task.id?.uuidString ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling time notification: \(error)")
            }
        }
    }

    private func scheduleLocationNotification(for task: TodoTask) {
        print("=== Scheduling Location Notification ===")

        // Location notifications require "Always" authorization
        let locationAuthStatus = LocationManager.shared.authorizationStatus
        print("Location authorization status: \(locationAuthStatus.rawValue)")

        guard LocationManager.shared.isLocationBasedNotificationsAvailable else {
            print("Skipping location notification - Always authorization required (current: \(locationAuthStatus.rawValue))")
            return
        }

        // Check if location notification is configured
        guard let poi = task.notificationLocation else {
            print("No POI configured for task")
            return
        }

        let distance = Int(task.locationNotificationDistance)
        guard distance > 0 else {
            print("Invalid distance: \(distance)")
            return
        }

        guard let taskId = task.id?.uuidString else {
            print("No task ID")
            return
        }

        let notificationTitle = task.title ?? "Task Reminder"
        let locationName = poi.name ?? "the location"

        print("Task: \(notificationTitle)")
        print("Location: \(locationName) at (\(poi.latitude), \(poi.longitude))")
        print("Distance: \(distance)m")

        // Store task info for region delegate
        activeLocationTasks[taskId] = notificationTitle

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Location Reminder"
        content.body = "\(notificationTitle) - You are near \(locationName)"
        content.sound = .default
        content.badge = 1
        content.userInfo = ["taskId": taskId, "locationName": locationName]

        // Create location-based trigger with UNLocationNotificationTrigger
        let center = CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)

        // Use a reasonable minimum radius (iOS recommends at least 100m for reliable detection)
        let effectiveRadius = max(CLLocationDistance(distance), 100)
        print("Effective radius: \(effectiveRadius)m")

        let region = CLCircularRegion(center: center, radius: effectiveRadius, identifier: taskId)
        region.notifyOnEntry = true
        region.notifyOnExit = false

        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)

        // Create request with task ID as identifier
        let request = UNNotificationRequest(identifier: taskId, content: content, trigger: trigger)

        // Schedule the notification via UNUserNotificationCenter
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("ERROR scheduling location notification: \(error.localizedDescription)")
            } else {
                print("SUCCESS: Scheduled UNLocationNotificationTrigger for task: \(notificationTitle)")
            }
        }

        // Also set up region monitoring via LocationManager for more reliable detection
        // This provides a backup mechanism and handles the case when user is already at location
        let locationManager = LocationManager.shared
        if locationManager.authorizationStatus == .authorizedAlways {
            print("Setting up CLLocationManager region monitoring as backup...")
            locationManager.startMonitoringRegion(
                identifier: taskId,
                center: center,
                radius: effectiveRadius
            )
        } else {
            print("Skipping CLLocationManager region monitoring - not Always authorized")
        }

        print("=== Location Notification Scheduling Complete ===")
    }

    func cancelLocationNotification(for task: TodoTask) {
        guard let taskId = task.id?.uuidString else { return }

        // Remove from active tasks
        activeLocationTasks.removeValue(forKey: taskId)

        // Cancel pending notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [taskId])

        // Stop region monitoring
        LocationManager.shared.stopMonitoringRegion(identifier: taskId)
    }

    // MARK: - Smart Notifications (Multiple POIs)

    /// Schedules location notifications for multiple POIs based on smart analysis
    func scheduleSmartNotifications(for task: TodoTask, matchingPOIs: [PointOfInterest]) {
        print("=== Scheduling Smart Notifications ===")
        print("Task: \(task.title ?? "unknown")")
        print("Matching POIs: \(matchingPOIs.count)")

        // Location notifications require "Always" authorization
        guard LocationManager.shared.isLocationBasedNotificationsAvailable else {
            print("Skipping smart notifications - Always authorization required")
            return
        }

        guard let taskId = task.id?.uuidString else {
            print("No task ID")
            return
        }

        // Cancel any existing notifications for this task
        cancelSmartNotifications(for: task)

        let notificationTitle = task.title ?? "Task Reminder"
        let distance = Int(task.locationNotificationDistance)
        let effectiveRadius = max(CLLocationDistance(distance > 0 ? distance : 15), 100)

        // Get the category display name for the notification
        let categoryName: String
        if let categoryRawValue = task.smartLocationCategory,
           let category = LocationCategory(rawValue: categoryRawValue) {
            categoryName = category.displayName
        } else {
            categoryName = "saved locations"
        }

        // Store task info for region delegate
        activeLocationTasks[taskId] = notificationTitle

        // Limit to a reasonable number of POIs (iOS has a limit of ~20 monitored regions)
        let poisToMonitor = Array(matchingPOIs.prefix(10))

        for (index, poi) in poisToMonitor.enumerated() {
            let poiId = "\(taskId)_poi\(index)"
            let locationName = poi.name ?? "a location"

            print("Setting up notification for POI \(index + 1): \(locationName)")

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Smart Reminder"
            content.body = "\(notificationTitle) - You are near \(locationName)"
            content.sound = .default
            content.badge = 1
            content.userInfo = [
                "taskId": taskId,
                "poiId": poiId,
                "locationName": locationName,
                "isSmart": true,
                "categoryName": categoryName
            ]

            // Create location-based trigger
            let center = CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)
            let region = CLCircularRegion(center: center, radius: effectiveRadius, identifier: poiId)
            region.notifyOnEntry = true
            region.notifyOnExit = false

            let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
            let request = UNNotificationRequest(identifier: poiId, content: content, trigger: trigger)

            // Schedule the notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("ERROR scheduling smart notification for \(locationName): \(error.localizedDescription)")
                } else {
                    print("SUCCESS: Scheduled smart notification for \(locationName)")
                }
            }

            // Also set up region monitoring via LocationManager for more reliable detection
            let locationManager = LocationManager.shared
            if locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startMonitoringRegion(
                    identifier: poiId,
                    center: center,
                    radius: effectiveRadius
                )
            }
        }

        print("=== Smart Notifications Scheduling Complete: \(poisToMonitor.count) regions ===")
    }

    /// Cancels all smart notifications for a task
    func cancelSmartNotifications(for task: TodoTask) {
        guard let taskId = task.id?.uuidString else { return }

        // Remove from active tasks
        activeLocationTasks.removeValue(forKey: taskId)

        // Cancel all POI-specific notifications (up to 10)
        var identifiersToCancel = [taskId]
        for i in 0..<10 {
            identifiersToCancel.append("\(taskId)_poi\(i)")
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)

        // Stop region monitoring for all POIs
        for identifier in identifiersToCancel {
            LocationManager.shared.stopMonitoringRegion(identifier: identifier)
        }
    }

    // MARK: - Setup All Location-Based Task Monitoring

    func setupLocationMonitoringForAllTasks(context: NSManagedObjectContext) {
        // Location monitoring requires "Always" authorization
        guard LocationManager.shared.isLocationBasedNotificationsAvailable else {
            print("Skipping location monitoring setup - Always authorization required")
            return
        }

        self.managedObjectContext = context

        // Fetch location-based tasks
        let locationFetchRequest: NSFetchRequest<TodoTask> = TodoTask.fetchRequest()
        locationFetchRequest.predicate = NSPredicate(format: "isCompleted == NO AND notificationType == %@", "location")

        do {
            let locationTasks = try context.fetch(locationFetchRequest)
            print("Setting up location monitoring for \(locationTasks.count) location-based tasks")

            for task in locationTasks {
                if task.notificationLocation != nil && task.locationNotificationDistance > 0 {
                    scheduleLocationNotification(for: task)
                }
            }
        } catch {
            print("Error fetching location-based tasks: \(error)")
        }

        // Fetch smart notification tasks
        let smartFetchRequest: NSFetchRequest<TodoTask> = TodoTask.fetchRequest()
        smartFetchRequest.predicate = NSPredicate(format: "isCompleted == NO AND notificationType == %@", "smart")

        do {
            let smartTasks = try context.fetch(smartFetchRequest)
            print("Setting up location monitoring for \(smartTasks.count) smart notification tasks")

            for task in smartTasks {
                if let categoryRawValue = task.smartLocationCategory,
                   let category = LocationCategory(rawValue: categoryRawValue) {
                    let matchingPOIs = TaskCategoryAnalyzer.findMatchingPOIs(for: [category], in: context)
                    if !matchingPOIs.isEmpty {
                        scheduleSmartNotifications(for: task, matchingPOIs: matchingPOIs)
                    }
                }
            }
        } catch {
            print("Error fetching smart notification tasks: \(error)")
        }
    }

    // MARK: - Trigger Notification Manually (for region delegate)

    func triggerLocationNotification(taskId: String) {
        guard let context = managedObjectContext else {
            print("No managed object context available for triggering notification")
            return
        }

        guard let uuid = UUID(uuidString: taskId) else {
            print("Invalid task ID format: \(taskId)")
            return
        }

        let fetchRequest: NSFetchRequest<TodoTask> = TodoTask.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)

        do {
            let tasks = try context.fetch(fetchRequest)
            guard let task = tasks.first, !task.isCompleted else {
                print("Task not found or already completed: \(taskId)")
                return
            }

            guard let poi = task.notificationLocation else {
                return
            }

            let notificationTitle = task.title ?? "Task Reminder"
            let locationName = poi.name ?? "the location"
            let distance = Int(task.locationNotificationDistance)

            // Create and deliver notification immediately
            let content = UNMutableNotificationContent()
            content.title = "Location Reminder"
            content.body = "\(notificationTitle) - You are within \(distance) metre\(distance == 1 ? "" : "s") of \(locationName)"
            content.sound = .default
            content.badge = 1

            // Immediate trigger
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            let request = UNNotificationRequest(
                identifier: "immediate-\(taskId)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error triggering immediate notification: \(error)")
                } else {
                    print("Triggered location notification for: \(notificationTitle)")
                }
            }

            // Stop monitoring this region after triggering (one-time notification)
            LocationManager.shared.stopMonitoringRegion(identifier: taskId)
            activeLocationTasks.removeValue(forKey: taskId)

        } catch {
            print("Error fetching task for notification: \(error)")
        }
    }
    
    func cancelNotification(for task: TodoTask) {
        guard let taskId = task.id else { return }
        let identifier = taskId.uuidString

        // Remove from active location tasks
        activeLocationTasks.removeValue(forKey: identifier)

        // Cancel pending notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier, "immediate-\(identifier)"])

        // Stop region monitoring based on notification type
        let notificationType = task.notificationType ?? "smart"
        switch notificationType {
        case "location":
            LocationManager.shared.stopMonitoringRegion(identifier: identifier)
        case "smart":
            cancelSmartNotifications(for: task)
        default:
            break
        }
    }
    
    func scheduleNotificationsForTodayTasks(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<TodoTask> = TodoTask.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == NO")

        do {
            let tasks = try context.fetch(fetchRequest)

            for task in tasks {
                let notificationType = task.notificationType ?? "time"

                if notificationType == "location" {
                    // Location-based notification - schedule if POI is set
                    if task.notificationLocation != nil && task.locationNotificationDistance > 0 {
                        scheduleNotification(for: task)
                    } else {
                        cancelNotification(for: task)
                    }
                } else {
                    // Time-based notification
                    var taskDate: Date?

                    if let dateType = task.dateType {
                        if dateType == "dueDate", let dueDate = task.dueDate {
                            taskDate = dueDate
                        } else if dateType == "toBeDoneIn", let endDate = task.endDate {
                            taskDate = endDate
                        }
                    }

                    // Schedule notification if task has a due date and notification is enabled
                    if let date = taskDate, task.notificationMinutes > 0 {
                        // Calculate notification date
                        let notificationDate = date.addingTimeInterval(-Double(task.notificationMinutes) * 60)
                        // Only schedule if notification is in the future
                        if notificationDate >= Date() {
                            scheduleNotification(for: task)
                        } else {
                            cancelNotification(for: task)
                        }
                    } else {
                        cancelNotification(for: task)
                    }
                }
            }
        } catch {
            print("Error fetching tasks for notifications: \(error)")
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Region Entry Delegate

extension NotificationManager: RegionEntryDelegate {
    func didEnterRegion(identifier: String) {
        print("NotificationManager: User entered region \(identifier)")

        // Check if this is an active location task
        guard activeLocationTasks[identifier] != nil else {
            print("Region \(identifier) is not an active location task")
            return
        }

        // Trigger notification for this task
        triggerLocationNotification(taskId: identifier)
    }

    func didExitRegion(identifier: String) {
        // We don't need to do anything on exit for now
        print("NotificationManager: User exited region \(identifier)")
    }
}

