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
    @State private var dueDate: Date = Date()
    @State private var selectedGroup: Group?
    @State private var showingPastDateError = false
    
    private var isDueDateValid: Bool {
        return dueDate >= Date()
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
                
                Section(header: Text("Due Date"), footer: showingPastDateError ? Text("Due date cannot be in the past").foregroundColor(.red) : nil) {
                    DatePicker("Due Date", selection: $dueDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: dueDate) { oldValue, newValue in
                            showingPastDateError = newValue < Date()
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
                    .disabled(title.isEmpty || !isDueDateValid)
                }
            }
            .onAppear {
                if let task = task {
                    title = task.title ?? ""
                    // Ensure due date is not in the past
                    let taskDueDate = task.dueDate ?? Date()
                    dueDate = taskDueDate < Date() ? Date() : taskDueDate
                    selectedGroup = task.group
                    showingPastDateError = false
                } else {
                    // For new tasks, ensure due date is not in the past
                    if dueDate < Date() {
                        dueDate = Date()
                    }
                    showingPastDateError = false
                }
            }
        }
    }
    
    private func saveTask() {
        withAnimation {
            // Validate due date is not in the past
            if dueDate < Date() {
                showingPastDateError = true
                return
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
            
            do {
                try viewContext.save()
                // Schedule notification if task is due today
                notificationManager.scheduleNotification(for: taskToSave)
                dismiss()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

