//
//  ContentView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Binding var pendingSharedText: String?
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
    @State private var highlightFrames: [TourStep: CGRect] = [:]
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: TodoTask?
    @State private var showingNotesImport = false

    private var hasCompletedTasks: Bool {
        tasks.contains { $0.isCompleted }
    }

    private var completedTasksCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    private var pendingTasksCount: Int {
        tasks.filter { !$0.isCompleted }.count
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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning"
        } else if hour < 17 {
            return "Good Afternoon"
        } else {
            return "Good Evening"
        }
    }

    private var firstName: String {
        authManager.userName.split(separator: " ").first.map(String.init) ?? "there"
    }

    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    if tasks.isEmpty {
                        emptyStateView
                            .tourHighlight(for: .taskList)
                    } else {
                        taskListView
                            .tourHighlight(for: .taskList)
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle("My Tasks")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        profileButton
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        trailingToolbarItems
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
                .sheet(isPresented: $showingNotesImport) {
                    NotesImportView(initialText: pendingSharedText)
                        .onDisappear {
                            pendingSharedText = nil
                        }
                }
                .onChange(of: pendingSharedText) { _, newValue in
                    if newValue != nil {
                        showingNotesImport = true
                    }
                }
                .alert("Clear Completed Tasks?", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Clear \(completedTasksCount)", role: .destructive) {
                        clearCompletedTasks()
                    }
                } message: {
                    Text("This will permanently remove \(completedTasksCount) completed task\(completedTasksCount == 1 ? "" : "s").")
                }
                .onAppear {
                    notificationManager.scheduleNotificationsForTodayTasks(context: viewContext)
                }
            }
            .navigationViewStyle(.stack)
            .onPreferenceChange(HighlightFramePreferenceKey.self) { frames in
                highlightFrames = frames
            }

            GuidedTourOverlay(tourManager: tourManager, highlightFrames: highlightFrames)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 12) {
                Text("All Clear!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("You don't have any tasks yet.\nTap the + button to create your first task.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                selectedTask = nil
                showingAddTask = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Create Task")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(25)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Task List View

    private var taskListView: some View {
        List {
            if hasCompletedTasks {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(pendingTasksCount) pending")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("\(completedTasksCount) completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            showingDeleteAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("Clear Done")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                ForEach(tasks) { task in
                    TaskRow(task: task, onToggleComplete: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        toggleTaskCompletion(task)
                    }, onTapTask: {
                        let selectionFeedback = UISelectionFeedbackGenerator()
                        selectionFeedback.selectionChanged()
                        selectedTask = task
                        showingAddTask = true
                    })
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteTasks)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            showingUserProfile = true
        }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Text(userInitials)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .tourHighlight(for: .profileButton)
        .accessibilityLabel("User profile")
        .accessibilityHint("Opens your account settings")
    }

    // MARK: - Trailing Toolbar Items

    private var trailingToolbarItems: some View {
        HStack(spacing: 16) {
            HelpButton(screenType: .taskList)

            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                showingPointOfInterestManager = true
            }) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
            }
            .tourHighlight(for: .locationButton)
            .accessibilityLabel("Manage locations")
            .accessibilityHint("Opens points of interest manager")

            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                showingNotesImport = true
            }) {
                Image(systemName: "note.text")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
            }
            .tourHighlight(for: .notesImportButton)
            .accessibilityLabel("Import from notes")
            .accessibilityHint("Import tasks from notes with smart grouping")

            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                selectedTask = nil
                showingAddTask = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }
            .tourHighlight(for: .addTaskButton)
            .accessibilityLabel("Add new task")
            .accessibilityHint("Creates a new task")
        }
    }
    
    // MARK: - Actions

    private func toggleTaskCompletion(_ task: TodoTask) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            task.isCompleted.toggle()

            if task.isCompleted {
                notificationManager.cancelNotification(for: task)
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
            } else {
                notificationManager.scheduleNotification(for: task)
            }

            saveContext()
        }
    }

    private func deleteTasks(offsets: IndexSet) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        withAnimation {
            let tasksToDelete = offsets.map { tasks[$0] }
            tasksToDelete.forEach { notificationManager.cancelNotification(for: $0) }
            tasksToDelete.forEach(viewContext.delete)
            saveContext()
        }
    }

    private func clearCompletedTasks() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        withAnimation {
            let completedTasks = tasks.filter { $0.isCompleted }
            completedTasks.forEach { notificationManager.cancelNotification(for: $0) }
            completedTasks.forEach { viewContext.delete($0) }
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error saving context: \(nsError), \(nsError.userInfo)")
        }
    }
}

#Preview {
    ContentView(pendingSharedText: .constant(nil))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(NotificationManager.shared)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(GuidedTourManager.shared)
}
