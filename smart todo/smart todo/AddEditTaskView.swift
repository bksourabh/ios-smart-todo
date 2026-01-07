//
//  AddEditTaskView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

struct AddEditTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    
    var task: TodoTask?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.name, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<Group>
    
    @State private var title: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(6 * 60)
    @State private var selectedGroup: Group?
    @State private var showingPastDateError = false
    @State private var showingDateTooSoonError = false
    @State private var showingNotificationPastError = false
    @State private var notificationMinutes: Int = 0
    
    private var isDueDateValid: Bool {
        let now = Date()
        let fiveMinutesFromNow = now.addingTimeInterval(5 * 60)
        // Due date must be strictly more than 5 minutes in the future
        return dueDate > fiveMinutesFromNow
    }
    
    private var isNotificationValid: Bool {
        guard notificationMinutes > 0 else { return true } // 0 means no notification
        let notificationDate = dueDate.addingTimeInterval(-Double(notificationMinutes) * 60)
        return notificationDate >= Date()
    }
    
    @ViewBuilder
    private var dueDateFooter: some View {
        if showingDateTooSoonError {
            Text("Due date must be at least 5 minutes from now").foregroundColor(.red)
        } else if showingPastDateError {
            Text("Due date cannot be in the past").foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var notificationFooter: some View {
        if showingNotificationPastError {
            Text("Notification cannot be in the past. Please adjust the due date or notification time.").foregroundColor(.red)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                }
                
                Section(header: Text("Group")) {
                    Picker("Group", selection: $selectedGroup) {
                        Text("None").tag(nil as Group?)
                        ForEach(groups) { group in
                            Text(group.name ?? "Unnamed Group").tag(group as Group?)
                        }
                    }
                }
                
                Section(header: Text("Due Date"), footer: dueDateFooter) {
                    DatePicker("Due Date", selection: $dueDate, in: Date().addingTimeInterval(5 * 60 + 1)..., displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: dueDate) { oldValue, newValue in
                            let now = Date()
                            let fiveMinutesFromNow = now.addingTimeInterval(5 * 60)
                            showingPastDateError = newValue <= now
                            // Due date must be strictly more than 5 minutes in the future
                            showingDateTooSoonError = newValue <= fiveMinutesFromNow
                            // Clear errors if date is now valid (strictly more than 5 minutes)
                            if newValue > fiveMinutesFromNow {
                                showingPastDateError = false
                                showingDateTooSoonError = false
                            }
                            // Revalidate notification when due date changes
                            if notificationMinutes > 0 {
                                let notificationDate = newValue.addingTimeInterval(-Double(notificationMinutes) * 60)
                                showingNotificationPastError = notificationDate < Date()
                                // Clear error if notification is now valid
                                if notificationDate >= Date() {
                                    showingNotificationPastError = false
                                }
                            } else {
                                showingNotificationPastError = false
                            }
                        }
                }
                
                Section(header: Text("Notification"), footer: notificationFooter) {
                    Picker(selection: $notificationMinutes, label: Text(notificationMinutes == 0 ? "Notify me x minutes before" : "Notify me \(notificationMinutes) minute\(notificationMinutes == 1 ? "" : "s") before")) {
                        Text("No notification").tag(0)
                        ForEach(1...60, id: \.self) { minutes in
                            Text("\(minutes) minute\(minutes == 1 ? "" : "s")").tag(minutes)
                        }
                    }
                    .onChange(of: notificationMinutes) { oldValue, newValue in
                        if newValue > 0 {
                            let notificationDate = dueDate.addingTimeInterval(-Double(newValue) * 60)
                            showingNotificationPastError = notificationDate < Date()
                            // Clear error if notification is now valid
                            if notificationDate >= Date() {
                                showingNotificationPastError = false
                            }
                        } else {
                            showingNotificationPastError = false
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    // Disable Save when title is empty or current values are invalid
                    .disabled(title.isEmpty || !isDueDateValid || !isNotificationValid)
                }
            }
            .onAppear {
                if let task = task {
                    title = task.title ?? ""
                    // Ensure due date is strictly more than 5 minutes in the future
                    let taskDueDate = task.dueDate ?? Date()
                    let now = Date()
                    let fiveMinutesFromNow = now.addingTimeInterval(5 * 60)
                    // Add 1 second to ensure it's strictly more than 5 minutes
                    dueDate = taskDueDate <= fiveMinutesFromNow ? fiveMinutesFromNow.addingTimeInterval(1) : taskDueDate
                    selectedGroup = task.group
                    notificationMinutes = Int(task.notificationMinutes)
                    showingPastDateError = false
                    showingDateTooSoonError = false
                    showingNotificationPastError = false
                } else {
                    // For new tasks, set default due date to 6 minutes in the future
                    let now = Date()
                    let sixMinutesFromNow = now.addingTimeInterval(6 * 60)
                    dueDate = sixMinutesFromNow
                    // Default notification is 1 minute before
                    notificationMinutes = 1
                    showingPastDateError = false
                    showingDateTooSoonError = false
                    showingNotificationPastError = false
                }
            }
        }
    }
    
    private func saveTask() {
        withAnimation {
            // Clear previous error flags
            showingPastDateError = false
            showingDateTooSoonError = false
            showingNotificationPastError = false
            
            // Validate due date is strictly more than 5 minutes in the future
            let now = Date()
            let fiveMinutesFromNow = now.addingTimeInterval(5 * 60)
            if dueDate <= now {
                showingPastDateError = true
                return
            }
            if dueDate <= fiveMinutesFromNow {
                showingDateTooSoonError = true
                return
            }
            
            // Validate notification is not in the past
            if notificationMinutes > 0 {
                let notificationDate = dueDate.addingTimeInterval(-Double(notificationMinutes) * 60)
                if notificationDate < Date() {
                    showingNotificationPastError = true
                    return
                }
            }
            
            let taskToSave: TodoTask
            if let existingTask = task {
                taskToSave = existingTask
            } else {
                taskToSave = TodoTask(context: viewContext)
                taskToSave.id = UUID()
                taskToSave.createdAt = Date()
                taskToSave.isCompleted = false
            }
            
            taskToSave.title = title
            taskToSave.dateType = "dueDate"
            taskToSave.group = selectedGroup
            taskToSave.dueDate = dueDate
            taskToSave.startDate = nil
            taskToSave.endDate = nil
            taskToSave.notificationMinutes = Int16(notificationMinutes)
            
            do {
                try viewContext.save()
                // Schedule notification
                notificationManager.scheduleNotification(for: taskToSave)
                dismiss()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

