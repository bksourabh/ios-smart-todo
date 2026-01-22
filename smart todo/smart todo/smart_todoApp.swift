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

@main
struct smart_todoApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var tourManager = GuidedTourManager.shared
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            mainView
                .animation(.easeInOut, value: authManager.isAuthenticated)
                .animation(.easeInOut, value: tourManager.isOnboardingComplete)
                .animation(.easeInOut, value: tourManager.isPOISetupComplete)
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
                            // Schedule notifications for today's tasks
                            notificationManager.scheduleNotificationsForTodayTasks(context: persistenceController.container.viewContext)

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
                    }
            }
        } else {
            LoginView(authManager: authManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
