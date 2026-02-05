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
    @ObservedObject private var locationManager = LocationManager.shared
    @FocusState private var isTitleFocused: Bool

    var task: TodoTask?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PointOfInterest.name, ascending: true)],
        animation: .default)
    private var pointsOfInterest: FetchedResults<PointOfInterest>

    @State private var title: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(6 * 60)
    @State private var showingPastDateError = false
    @State private var showingDateTooSoonError = false
    @State private var showingNotificationPastError = false
    @State private var notificationMinutes: Int = 0

    // Location-based notification state
    @State private var notificationType: String = "time"
    @State private var locationNotificationDistance: Int = 15
    @State private var selectedPOI: PointOfInterest?
    @State private var showingAddPOI = false

    private var isLocationNotificationsEnabled: Bool {
        return locationManager.isLocationBasedNotificationsAvailable
    }

    private var isEditing: Bool {
        task != nil
    }

    private var isDueDateValid: Bool {
        guard notificationType == "time" else { return true }
        let now = Date()
        let fiveMinutesFromNow = now.addingTimeInterval(5 * 60)
        return dueDate > fiveMinutesFromNow
    }

    private var isNotificationValid: Bool {
        guard notificationType == "time" else { return true }
        guard notificationMinutes > 0 else { return true }
        let notificationDate = dueDate.addingTimeInterval(-Double(notificationMinutes) * 60)
        return notificationDate >= Date()
    }

    private var isLocationNotificationValid: Bool {
        guard notificationType == "location" else { return true }
        return selectedPOI != nil
    }

    @ViewBuilder
    private var dueDateFooter: some View {
        if showingDateTooSoonError {
            Label("Due date must be at least 5 minutes from now", systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        } else if showingPastDateError {
            Label("Due date cannot be in the past", systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var notificationFooter: some View {
        if showingNotificationPastError {
            Label("Notification time would be in the past", systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // Task Title Section
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 24, height: 24)
                        }

                        TextField("What do you need to do?", text: $title)
                            .font(.system(size: 17))
                            .focused($isTitleFocused)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Task")
                } footer: {
                    if title.isEmpty {
                        Text("Enter a descriptive title for your task")
                    }
                }

                // Only show Due Date section for time-based notifications (or when location is disabled)
                if notificationType == "time" || !isLocationNotificationsEnabled {
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
                }

                Section(header: Text("Notification"), footer: notificationType == "time" ? notificationFooter : nil) {
                    if isLocationNotificationsEnabled {
                        Picker("Notification Type", selection: $notificationType) {
                            Text("Time-based").tag("time")
                            Text("Location-based").tag("location")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    } else {
                        // Location notifications disabled - show info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Time-based")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)

                            HStack(spacing: 8) {
                                Image(systemName: "location.slash.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Location-based notifications require \"Always Allow\" location permission. Enable in Settings.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)

                            Button(action: openLocationSettings) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Open Settings")
                                }
                                .font(.caption)
                            }
                            .padding(.top, 4)
                        }
                    }

                    if notificationType == "time" || !isLocationNotificationsEnabled {
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
                    } else if isLocationNotificationsEnabled {
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
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text(isEditing ? "Edit Task" : "New Task")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        saveTask()
                    }) {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || !isDueDateValid || !isNotificationValid || !isLocationNotificationValid)
                }
            }
            .onAppear {
                isTitleFocused = task == nil
                if let task = task {
                    title = task.title ?? ""
                    // Ensure due date is strictly more than 5 minutes in the future
                    let taskDueDate = task.dueDate ?? Date()
                    let now = Date()
                    let fiveMinutesFromNow = now.addingTimeInterval(5 * 60)
                    // Add 1 second to ensure it's strictly more than 5 minutes
                    dueDate = taskDueDate <= fiveMinutesFromNow ? fiveMinutesFromNow.addingTimeInterval(1) : taskDueDate
                    notificationMinutes = Int(task.notificationMinutes)
                    // Load location notification fields
                    let savedNotificationType = task.notificationType ?? "time"
                    // Only use location type if it's available
                    notificationType = (savedNotificationType == "location" && !isLocationNotificationsEnabled) ? "time" : savedNotificationType
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
    
    private func openLocationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func saveTask() {
        withAnimation {
            // Clear previous error flags
            showingPastDateError = false
            showingDateTooSoonError = false
            showingNotificationPastError = false

            // Validate due date only for time-based notifications
            if notificationType == "time" {
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
            taskToSave.notificationType = notificationType

            // Save settings based on notification type
            if notificationType == "time" {
                taskToSave.dateType = "dueDate"
                taskToSave.dueDate = dueDate
                taskToSave.startDate = nil
                taskToSave.endDate = nil
                taskToSave.group = nil
                taskToSave.notificationMinutes = Int16(notificationMinutes)
                taskToSave.locationNotificationDistance = 0
                taskToSave.notificationLocation = nil
            } else {
                // Location-based notification - no due date needed
                taskToSave.dateType = "location"
                taskToSave.dueDate = nil
                taskToSave.startDate = nil
                taskToSave.endDate = nil
                taskToSave.group = nil
                taskToSave.notificationMinutes = 0
                taskToSave.locationNotificationDistance = Int16(locationNotificationDistance)
                taskToSave.notificationLocation = selectedPOI
            }

            do {
                try viewContext.save()
                notificationManager.scheduleNotification(for: taskToSave)

                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)

                dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving task: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

