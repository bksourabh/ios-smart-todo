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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    Task {
                        // Request notification permission on first launch
                        if notificationManager.authorizationStatus == .notDetermined {
                            _ = await notificationManager.requestAuthorization()
                        }
                        // Schedule notifications for today's tasks
                        notificationManager.scheduleNotificationsForTodayTasks(context: persistenceController.container.viewContext)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Reschedule notifications when app comes to foreground
                    notificationManager.checkAuthorizationStatus()
                    notificationManager.scheduleNotificationsForTodayTasks(context: persistenceController.container.viewContext)
                }
        }
    }
}
