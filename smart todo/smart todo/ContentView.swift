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
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var tourManager: GuidedTourManager

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
    @State private var showingUserProfile = false
    @State private var showingVoiceInput = false
    @State private var highlightFrames: [TourStep: CGRect] = [:]

    private var hasCompletedTasks: Bool {
        tasks.contains { $0.isCompleted }
    }

    private var userInitials: String {
        let names = authManager.userName.split(separator: " ")
        if names.count >= 2 {
            return String(names[0].prefix(1)) + String(names[1].prefix(1))
        } else if let first = names.first {
            return String(first.prefix(2))
        }
        return "U"
    }

    var body: some View {
        ZStack {
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
                        .tourHighlight(for: .taskList)
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
                        .tourHighlight(for: .taskList)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 12) {
                            // Profile button
                            Button(action: {
                                showingUserProfile = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Text(userInitials)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .tourHighlight(for: .profileButton)

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
                            HelpButton(screenType: .taskList)

                            Button(action: {
                                showingPointOfInterestManager = true
                            }) {
                                Image(systemName: "mappin.circle")
                            }
                            .tourHighlight(for: .locationButton)

                            Button(action: {
                                selectedTask = nil
                                showingAddTask = true
                            }) {
                                Image(systemName: "plus")
                            }
                            .tourHighlight(for: .addTaskButton)
                        }
                    }
                }
                .sheet(isPresented: $showingAddTask) {
                    AddEditTaskView(task: selectedTask)
                }
                .sheet(isPresented: $showingPointOfInterestManager) {
                    PointOfInterestManagerView()
                }
                .sheet(isPresented: $showingUserProfile) {
                    UserProfileView(authManager: authManager)
                }
                .sheet(isPresented: $showingVoiceInput) {
                    VoiceInputTaskView()
                }
                .onAppear {
                    // Reschedule notifications when view appears
                    notificationManager.scheduleNotificationsForTodayTasks(context: viewContext)
                }
            }
            .onPreferenceChange(HighlightFramePreferenceKey.self) { frames in
                highlightFrames = frames
            }

            // Guided tour overlay
            GuidedTourOverlay(tourManager: tourManager, highlightFrames: highlightFrames)

            // Floating voice input button
            if !tourManager.isShowingTour {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VoiceInputButton(showingVoiceInput: $showingVoiceInput)
                            .padding(.trailing, 20)
                            .padding(.bottom, 24)
                    }
                }
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
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(GuidedTourManager.shared)
}
