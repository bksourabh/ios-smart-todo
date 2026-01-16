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

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PointOfInterest.name, ascending: true)],
        animation: .default)
    private var pointsOfInterest: FetchedResults<PointOfInterest>

    @State private var title: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(6 * 60)
    @State private var selectedGroup: Group?
    @State private var showingPastDateError = false
    @State private var showingDateTooSoonError = false
    @State private var showingNotificationPastError = false
    @State private var notificationMinutes: Int = 0

    // Location-based notification state
    @State private var notificationType: String = "time"
    @State private var locationNotificationDistance: Int = 15
    @State private var selectedPOI: PointOfInterest?
    @State private var showingAddPOI = false
    
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
                    Picker("Notification Type", selection: $notificationType) {
                        Text("Time-based").tag("time")
                        Text("Location-based").tag("location")
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if notificationType == "time" {
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
                                if notificationDate >= Date() {
                                    showingNotificationPastError = false
                                }
                            } else {
                                showingNotificationPastError = false
                            }
                        }
                    } else {
                        // Location-based notification
                        Picker("Notification Distance", selection: $locationNotificationDistance) {
                            ForEach(1...50, id: \.self) { distance in
                                Text("\(distance) metre\(distance == 1 ? "" : "s")").tag(distance)
                            }
                        }

                        if pointsOfInterest.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No points of interest available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button(action: {
                                    showingAddPOI = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Point of Interest")
                                    }
                                }
                            }
                        } else {
                            Picker("Location", selection: $selectedPOI) {
                                Text("Select a location").tag(nil as PointOfInterest?)
                                ForEach(pointsOfInterest) { poi in
                                    Text(poi.name ?? "Unnamed").tag(poi as PointOfInterest?)
                                }
                            }

                            if let poi = selectedPOI {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let address = poi.address, !address.isEmpty {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text("Notify when \(locationNotificationDistance) metre\(locationNotificationDistance == 1 ? "" : "s") away")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
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
                    .disabled(title.isEmpty || !isDueDateValid || !isNotificationValid || (notificationType == "location" && selectedPOI == nil))
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
                    // Load location notification fields
                    notificationType = task.notificationType ?? "time"
                    locationNotificationDistance = Int(task.locationNotificationDistance)
                    if locationNotificationDistance == 0 { locationNotificationDistance = 15 }
                    selectedPOI = task.notificationLocation
                    showingPastDateError = false
                    showingDateTooSoonError = false
                    showingNotificationPastError = false
                } else {
                    // For new tasks, set default due date to 6 minutes in the future
                    let now = Date()
                    let sixMinutesFromNow = now.addingTimeInterval(6 * 60)
                    dueDate = sixMinutesFromNow
                    // Default notification is 1 minute before (time-based)
                    notificationMinutes = 1
                    notificationType = "time"
                    locationNotificationDistance = 15
                    selectedPOI = nil
                    showingPastDateError = false
                    showingDateTooSoonError = false
                    showingNotificationPastError = false
                }
            }
            .sheet(isPresented: $showingAddPOI) {
                PointOfInterestManagerView()
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

            // Save notification settings based on type
            taskToSave.notificationType = notificationType
            if notificationType == "time" {
                taskToSave.notificationMinutes = Int16(notificationMinutes)
                taskToSave.locationNotificationDistance = 0
                taskToSave.notificationLocation = nil
            } else {
                taskToSave.notificationMinutes = 0
                taskToSave.locationNotificationDistance = Int16(locationNotificationDistance)
                taskToSave.notificationLocation = selectedPOI
            }

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

