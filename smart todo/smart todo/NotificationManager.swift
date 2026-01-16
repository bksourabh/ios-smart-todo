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
    
    private init() {
        checkAuthorizationStatus()
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
        // Only schedule if notifications are authorized
        guard authorizationStatus == .authorized else {
            return
        }

        // Only schedule if task is not completed
        guard !task.isCompleted else {
            cancelNotification(for: task)
            return
        }

        // Cancel existing notification for this task
        cancelNotification(for: task)

        let notificationType = task.notificationType ?? "time"

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
        // Check if location notification is configured
        guard let poi = task.notificationLocation else {
            return
        }

        let distance = Int(task.locationNotificationDistance)
        guard distance > 0 else {
            return
        }

        let notificationTitle = task.title ?? "Task Reminder"
        let locationName = poi.name ?? "the location"

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Location Reminder"
        content.body = "\(notificationTitle) - You are \(distance) metre\(distance == 1 ? "" : "s") away from \(locationName)"
        content.sound = .default
        content.badge = 1

        // Create location-based trigger
        let center = CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)
        let region = CLCircularRegion(center: center, radius: CLLocationDistance(distance), identifier: task.id?.uuidString ?? UUID().uuidString)
        region.notifyOnEntry = true
        region.notifyOnExit = false

        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)

        // Create request with task ID as identifier
        let identifier = task.id?.uuidString ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling location notification: \(error)")
            }
        }
    }
    
    func cancelNotification(for task: TodoTask) {
        guard let taskId = task.id else { return }
        let identifier = taskId.uuidString
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
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

