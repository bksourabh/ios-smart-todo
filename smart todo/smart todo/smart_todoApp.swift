//
//  smart_todoApp.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData
import UIKit
import Combine
import CoreLocation

@main
struct smart_todoApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var tourManager = GuidedTourManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var pendingSharedText: String?

    private let appGroupID = "group.com.helpingthoughtgames.smart-todo"
    private let importFileName = "PendingImport.json"

    var body: some Scene {
        WindowGroup {
            mainView
                .animation(.easeInOut, value: authManager.isAuthenticated)
                .animation(.easeInOut, value: tourManager.isOnboardingComplete)
                .animation(.easeInOut, value: tourManager.isPOISetupComplete)
                .animation(.easeInOut, value: tourManager.isCalendarImportComplete)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    checkForSharedImport()
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "smarttodo", url.host == "import-notes" else { return }
        checkForSharedImport()
    }

    private func checkForSharedImport() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let fileURL = containerURL.appendingPathComponent(importFileName)

        do {
            let data = try Data(contentsOf: fileURL)
            let importData = try JSONDecoder().decode(SharedImportPayload.self, from: data)
            try? FileManager.default.removeItem(at: fileURL)
            importTasksFromShareExtension(importData)
        } catch {
            // File doesn't exist or isn't valid JSON — nothing to import
        }
    }

    private func importTasksFromShareExtension(_ payload: SharedImportPayload) {
        let context = persistenceController.container.viewContext
        var createdTasks: [(TodoTask, SharedImportCategory?)] = []

        for group in payload.groups {
            let todoTask = TodoTask(context: context)
            todoTask.id = UUID()
            todoTask.title = group.groupTitle
            todoTask.isCompleted = false
            todoTask.createdAt = Date()
            todoTask.dateType = "smart"
            todoTask.notificationType = "smart"
            todoTask.locationNotificationDistance = 15

            if let category = group.locationCategory {
                todoTask.smartLocationCategory = category.rawValue
            }

            for (subIndex, itemTitle) in group.items.enumerated() {
                let subTask = SubTask(context: context)
                subTask.id = UUID()
                subTask.title = itemTitle
                subTask.isCompleted = false
                subTask.createdAt = Date()
                subTask.sortOrder = Int16(subIndex)
                subTask.parentTask = todoTask
            }

            createdTasks.append((todoTask, group.locationCategory))
        }

        do {
            try context.save()

            // Schedule smart notifications using already-created task references
            for (task, importCategory) in createdTasks {
                if let categoryStr = importCategory?.rawValue,
                   let category = LocationCategory(rawValue: categoryStr) {
                    let matchingPOIs = TaskCategoryAnalyzer.findMatchingPOIs(for: [category], in: context)
                    if !matchingPOIs.isEmpty {
                        notificationManager.scheduleSmartNotifications(for: task, matchingPOIs: matchingPOIs)
                    }
                }
            }
        } catch {
            print("Error importing shared tasks: \(error)")
        }
    }

    @ViewBuilder
    private var mainView: some View {
        if authManager.isAuthenticated {
            if !tourManager.isOnboardingComplete {
                // Show onboarding carousel first
                OnboardingView(isOnboardingComplete: $tourManager.isOnboardingComplete) {
                    tourManager.isOnboardingComplete = true
                }
                .preferredColorScheme(themeManager.colorScheme)
            } else if !tourManager.isPOISetupComplete {
                // Show POI setup after onboarding
                POISetupView(
                    locationManager: locationManager,
                    isSetupComplete: $tourManager.isPOISetupComplete
                )
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(themeManager.colorScheme)
            } else if !tourManager.isCalendarImportComplete {
                // Show calendar import after POI setup
                CalendarImportSetupView(isSetupComplete: $tourManager.isCalendarImportComplete)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(notificationManager)
                    .preferredColorScheme(themeManager.colorScheme)
            } else {
                // Show main content with guided tour
                ContentView(pendingSharedText: $pendingSharedText)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(themeManager)
                    .environmentObject(notificationManager)
                    .environmentObject(authManager)
                    .environmentObject(tourManager)
                    .preferredColorScheme(themeManager.colorScheme)
                    .onAppear {
                        Task {
                            // Request notification permission on first launch
                            if notificationManager.authorizationStatus == .notDetermined {
                                _ = await notificationManager.requestAuthorization()
                            }

                            // Set up managed object context for NotificationManager
                            notificationManager.setManagedObjectContext(persistenceController.container.viewContext)

                            // Schedule time-based notifications
                            notificationManager.scheduleNotificationsForTodayTasks(context: persistenceController.container.viewContext)

                            // Set up location monitoring for location-based tasks
                            // Only if "Always" authorization is granted
                            if LocationManager.shared.authorizationStatus == .authorizedAlways {
                                notificationManager.setupLocationMonitoringForAllTasks(context: persistenceController.container.viewContext)
                            }

                            // Start guided tour if not completed
                            if !tourManager.hasCompletedTour {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    tourManager.startTour()
                                }
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        // Reschedule notifications when app comes to foreground
                        notificationManager.checkAuthorizationStatus()
                        notificationManager.scheduleNotificationsForTodayTasks(context: persistenceController.container.viewContext)

                        // Re-setup location monitoring only if "Always" authorized
                        if LocationManager.shared.authorizationStatus == .authorizedAlways {
                            notificationManager.setupLocationMonitoringForAllTasks(context: persistenceController.container.viewContext)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        // Check and refresh location authorization
                        LocationManager.shared.checkAuthorizationStatus()
                    }
            }
        } else {
            LoginView(authManager: authManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

// MARK: - Shared Import Payload (mirrors ShareExtension's SharedImportData)

private struct SharedImportPayload: Codable {
    let groups: [SharedImportGroup]
    let timestamp: Date
}

private struct SharedImportGroup: Codable {
    let id: UUID
    var groupTitle: String
    var locationCategory: SharedImportCategory?
    var items: [String]
}

private enum SharedImportCategory: String, Codable {
    case pharmacy
    case fuelStation = "fuel_station"
    case supermarket
    case grocery
    case restaurant
    case bank
    case postOffice = "post_office"
    case hardware
    case electronics
    case clothing
}
