//
//  smart_todoApp.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

@main
struct smart_todoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
