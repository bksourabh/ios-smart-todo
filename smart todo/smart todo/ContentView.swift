//
//  ContentView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var notificationManager: NotificationManager
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TodoTask.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TodoTask.createdAt, ascending: false)
        ],
        animation: .default)
    private var tasks: FetchedResults<TodoTask>
    
    @State private var showingAddTask = false
    @State private var selectedTask: TodoTask?
    @State private var showingPointOfInterestManager = false
    
    private var hasCompletedTasks: Bool {
        tasks.contains { $0.isCompleted }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if tasks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checklist")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No tasks yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Tap the + button to add your first task")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(tasks) { task in
                            TaskRow(task: task) {
                                toggleTaskCompletion(task)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTask = task
                                showingAddTask = true
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        if hasCompletedTasks {
                            Button(action: clearCompletedTasks) {
                                Text("Clear Completed")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showingPointOfInterestManager = true
                        }) {
                            Image(systemName: "mappin.circle")
                        }
                        Button(action: {
                            selectedTask = nil
                            showingAddTask = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskView(task: selectedTask)
            }
            .sheet(isPresented: $showingPointOfInterestManager) {
                PointOfInterestManagerView()
            }
            .onAppear {
                // Reschedule notifications when view appears
                notificationManager.scheduleNotificationsForTodayTasks(context: viewContext)
            }
        }
    }
    
    private func toggleTaskCompletion(_ task: TodoTask) {
        withAnimation {
            task.isCompleted.toggle()
            
            // Cancel notification if task is completed
            if task.isCompleted {
                notificationManager.cancelNotification(for: task)
            } else {
                // Reschedule notification if task is uncompleted and due today
                notificationManager.scheduleNotification(for: task)
            }
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            let tasksToDelete = offsets.map { tasks[$0] }
            // Cancel notifications for deleted tasks
            tasksToDelete.forEach { notificationManager.cancelNotification(for: $0) }
            tasksToDelete.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func clearCompletedTasks() {
        withAnimation {
            let completedTasks = tasks.filter { $0.isCompleted }
            // Cancel notifications for completed tasks being deleted
            completedTasks.forEach { notificationManager.cancelNotification(for: $0) }
            completedTasks.forEach { viewContext.delete($0) }
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(NotificationManager.shared)
}
