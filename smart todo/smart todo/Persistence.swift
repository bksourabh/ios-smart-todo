//
//  Persistence.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample tasks for preview
        let task1 = TodoTask(context: viewContext)
        task1.id = UUID()
        task1.title = "Complete project documentation"
        task1.isCompleted = false
        task1.dateType = "dueDate"
        task1.dueDate = Date().addingTimeInterval(86400) // Tomorrow
        task1.createdAt = Date()
        
        let task2 = TodoTask(context: viewContext)
        task2.id = UUID()
        task2.title = "Review code changes"
        task2.isCompleted = false
        task2.dateType = "toBeDoneIn"
        task2.startDate = Date()
        task2.endDate = Date().addingTimeInterval(7200) // 2 hours from now
        task2.createdAt = Date()
        
        let task3 = TodoTask(context: viewContext)
        task3.id = UUID()
        task3.title = "Overdue task example"
        task3.isCompleted = false
        task3.dateType = "dueDate"
        task3.dueDate = Date().addingTimeInterval(-86400) // Yesterday (overdue)
        task3.createdAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "smart_todo")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable lightweight migration so v1.0 stores upgrade automatically
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
