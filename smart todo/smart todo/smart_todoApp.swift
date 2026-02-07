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

    var body: some Scene {
        WindowGroup {
            mainView
                .animation(.easeInOut, value: authManager.isAuthenticated)
                .animation(.easeInOut, value: tourManager.isOnboardingComplete)
                .animation(.easeInOut, value: tourManager.isPOISetupComplete)
                .animation(.easeInOut, value: tourManager.isCalendarImportComplete)
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
                ContentView()
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
