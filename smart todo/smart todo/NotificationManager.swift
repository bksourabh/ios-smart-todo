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

        let notificationType = task.notificationType ?? "time"
        print("Notification type: \(notificationType)")

        if notificationType == "location" {
            scheduleLocationNotification(for: task)
        } else {
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

    // MARK: - Setup All Location-Based Task Monitoring

    func setupLocationMonitoringForAllTasks(context: NSManagedObjectContext) {
        // Location monitoring requires "Always" authorization
        guard LocationManager.shared.isLocationBasedNotificationsAvailable else {
            print("Skipping location monitoring setup - Always authorization required")
            return
        }

        self.managedObjectContext = context

        let fetchRequest: NSFetchRequest<TodoTask> = TodoTask.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == NO AND notificationType == %@", "location")

        do {
            let tasks = try context.fetch(fetchRequest)
            print("Setting up location monitoring for \(tasks.count) location-based tasks")

            for task in tasks {
                if task.notificationLocation != nil && task.locationNotificationDistance > 0 {
                    scheduleLocationNotification(for: task)
                }
            }
        } catch {
            print("Error fetching location-based tasks: \(error)")
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

        // Stop region monitoring if it's a location-based task
        if task.notificationType == "location" {
            LocationManager.shared.stopMonitoringRegion(identifier: identifier)
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

