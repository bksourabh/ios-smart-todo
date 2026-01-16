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
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TodoTask.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TodoTask.createdAt, ascending: false)
        ],
        animation: .default)
    private var allTasks: FetchedResults<TodoTask>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.name, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<Group>
    
    @State private var showingAddTask = false
    @State private var selectedTask: TodoTask?
    @State private var showingGroupManager = false
    @State private var showingPointOfInterestManager = false
    @State private var selectedFilterGroup: Group?
    
    private var tasks: [TodoTask] {
        if let selectedFilterGroup = selectedFilterGroup {
            return allTasks.filter { $0.group == selectedFilterGroup }
        } else {
            return Array(allTasks)
        }
    }
    
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
                        Text(selectedFilterGroup == nil ? "No tasks yet" : "No tasks in this group")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text(selectedFilterGroup == nil ? "Tap the + button to add your first task" : "Add tasks to this group or change the filter")
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
                ToolbarItem(placement: .principal) {
                    Menu {
                            Button(action: {
                                selectedFilterGroup = nil
                            }) {
                                HStack {
                                    Text("All Tasks")
                                    if selectedFilterGroup == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Divider()
                            ForEach(groups) { group in
                                Button(action: {
                                    selectedFilterGroup = group
                                }) {
                                    HStack {
                                        Text(group.name ?? "Unnamed Group")
                                        if selectedFilterGroup == group {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                if let selectedGroup = selectedFilterGroup {
                                    Text(selectedGroup.name ?? "Filtered")
                                        .font(.subheadline)
                                } else {
                                    Text("All")
                                        .font(.subheadline)
                                }
                            }
                        }
                }
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
                            showingGroupManager = true
                        }) {
                            Image(systemName: "folder")
                        }
                        Button(action: {
                            themeManager.toggleTheme()
                        }) {
                            Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                                .foregroundColor(.primary)
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
            .sheet(isPresented: $showingGroupManager) {
                GroupManagerView()
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
        .environmentObject(ThemeManager())
        .environmentObject(NotificationManager.shared)
}
