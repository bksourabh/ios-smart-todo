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
    @State private var notificationType: String = "smart"  // Default to smart
    @State private var locationNotificationDistance: Int = 15
    @State private var selectedPOI: PointOfInterest?
    @State private var showingAddPOI = false

    // Smart notification state
    @State private var detectedCategories: [LocationCategory] = []
    @State private var matchingPOIs: [PointOfInterest] = []
    @State private var isAnalyzing: Bool = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var lastAnalyzedTitle: String = ""

    // Subtask state
    @State private var subTaskTitles: [String] = []
    @State private var newSubTaskTitle: String = ""

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

    private var isSmartNotificationValid: Bool {
        // Smart notification is always valid - it can work without matching locations
        return true
    }

    private var hasMatchingLocations: Bool {
        return !matchingPOIs.isEmpty
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

                // Subtasks Section
                subTasksSection

                // Only show Due Date section for time-based notifications
                if notificationType == "time" {
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

                Section(header: Text("Notification Type")) {
                    // Notification type picker - always show all 3 options
                    Picker("Type", selection: $notificationType) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Smart")
                        }.tag("smart")
                        HStack {
                            Image(systemName: "clock")
                            Text("Time")
                        }.tag("time")
                        HStack {
                            Image(systemName: "location")
                            Text("Location")
                        }.tag("location")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: notificationType) { _, newValue in
                        if newValue == "smart" {
                            analyzeTaskForSmartNotification()
                        }
                    }

                    // Smart notification info
                    if notificationType == "smart" {
                        smartNotificationSection
                    }

                    // Time-based options
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

                        if showingNotificationPastError {
                            Label("Notification time would be in the past", systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // Location-based options
                    if notificationType == "location" {
                        if !isLocationNotificationsEnabled {
                            // Location notifications disabled - show info
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.slash.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Location-based notifications require \"Always Allow\" location permission.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Button(action: openLocationSettings) {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("Open Settings")
                                    }
                                    .font(.caption)
                                }
                            }
                        } else {
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
                    dueDate = taskDueDate <= fiveMinutesFromNow ? fiveMinutesFromNow.addingTimeInterval(1) : taskDueDate
                    notificationMinutes = Int(task.notificationMinutes)
                    // Load notification type
                    let savedNotificationType = task.notificationType ?? "smart"
                    notificationType = savedNotificationType
                    locationNotificationDistance = Int(task.locationNotificationDistance)
                    if locationNotificationDistance == 0 { locationNotificationDistance = 15 }
                    selectedPOI = task.notificationLocation
                    showingPastDateError = false
                    showingDateTooSoonError = false
                    showingNotificationPastError = false
                    // Load existing subtasks
                    if let existingSubTasks = task.subTasks as? Set<SubTask> {
                        subTaskTitles = existingSubTasks
                            .sorted { $0.sortOrder < $1.sortOrder }
                            .compactMap { $0.title }
                    }
                    // Analyze for smart notification if applicable
                    if savedNotificationType == "smart" {
                        analyzeTaskForSmartNotification()
                    }
                } else {
                    // For new tasks, default to Smart notification
                    let now = Date()
                    let sixMinutesFromNow = now.addingTimeInterval(6 * 60)
                    dueDate = sixMinutesFromNow
                    notificationMinutes = 1
                    notificationType = "smart"  // Default to smart
                    locationNotificationDistance = 15
                    selectedPOI = nil
                    showingPastDateError = false
                    showingDateTooSoonError = false
                    showingNotificationPastError = false
                }
            }
            .onChange(of: title) { _, _ in
                if notificationType == "smart" {
                    analyzeTaskForSmartNotification()
                }
            }
            .sheet(isPresented: $showingAddPOI) {
                PointOfInterestManagerView()
            }
            .onDisappear {
                // Cancel any pending analysis when view disappears
                analysisTask?.cancel()
                analysisTask = nil
            }
        }
        .navigationViewStyle(.stack)
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
            switch notificationType {
            case "time":
                taskToSave.dateType = "dueDate"
                taskToSave.dueDate = dueDate
                taskToSave.startDate = nil
                taskToSave.endDate = nil
                taskToSave.group = nil
                taskToSave.notificationMinutes = Int16(notificationMinutes)
                taskToSave.locationNotificationDistance = 0
                taskToSave.notificationLocation = nil
                taskToSave.smartLocationCategory = nil

            case "location":
                taskToSave.dateType = "location"
                taskToSave.dueDate = nil
                taskToSave.startDate = nil
                taskToSave.endDate = nil
                taskToSave.group = nil
                taskToSave.notificationMinutes = 0
                taskToSave.locationNotificationDistance = Int16(locationNotificationDistance)
                taskToSave.notificationLocation = selectedPOI
                taskToSave.smartLocationCategory = nil

            case "smart":
                // Smart notification - auto-detect locations
                taskToSave.dateType = "smart"
                taskToSave.dueDate = nil
                taskToSave.startDate = nil
                taskToSave.endDate = nil
                taskToSave.group = nil
                taskToSave.notificationMinutes = 0
                taskToSave.locationNotificationDistance = Int16(locationNotificationDistance)
                // Store the primary category for display purposes
                if let primaryCategory = detectedCategories.first {
                    taskToSave.smartLocationCategory = primaryCategory.rawValue
                }
                // Don't set a specific POI - the notification manager will handle multiple POIs
                taskToSave.notificationLocation = nil

            default:
                break
            }

            // Save subtasks
            // Remove existing subtasks first (for edit case)
            if let existingSubTasks = taskToSave.subTasks as? Set<SubTask> {
                for st in existingSubTasks {
                    viewContext.delete(st)
                }
            }
            // Create new subtasks
            let filteredSubTasks = subTaskTitles.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for (index, subTitle) in filteredSubTasks.enumerated() {
                let subTask = SubTask(context: viewContext)
                subTask.id = UUID()
                subTask.title = subTitle
                subTask.isCompleted = false
                subTask.createdAt = Date()
                subTask.sortOrder = Int16(index)
                subTask.parentTask = taskToSave
            }

            do {
                try viewContext.save()

                // Schedule notifications based on type
                if notificationType == "smart" && !matchingPOIs.isEmpty {
                    // Schedule notifications for all matching POIs
                    notificationManager.scheduleSmartNotifications(for: taskToSave, matchingPOIs: matchingPOIs)
                } else {
                    notificationManager.scheduleNotification(for: taskToSave)
                }

                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)

                dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving task: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Subtasks Section

    private var subTasksSection: some View {
        Section(header: Text("Subtasks")) {
            ForEach(subTaskTitles.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    TextField("Subtask", text: $subTaskTitles[index])
                        .font(.system(size: 15))

                    Button(action: {
                        let i = index
                        withAnimation {
                            subTaskTitles.remove(at: i)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                    .frame(width: 20)

                TextField("Add subtask", text: $newSubTaskTitle)
                    .font(.system(size: 15))
                    .onSubmit {
                        addNewSubTask()
                    }

                if !newSubTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add") {
                        addNewSubTask()
                    }
                    .font(.system(size: 14, weight: .medium))
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Subtask Helpers

    private func addNewSubTask() {
        let trimmed = newSubTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            subTaskTitles.append(trimmed)
            newSubTaskTitle = ""
        }
    }

    // MARK: - Smart Notification Section

    private var smartNotificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Info about smart mode
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart mode analyzes your task and automatically notifies you when near relevant locations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if SmartTaskAnalyzer.shared.isAppleIntelligenceAvailable {
                        HStack(spacing: 4) {
                            Image(systemName: "apple.intelligence")
                                .font(.system(size: 10))
                            Text("Powered by Apple Intelligence")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.purple)
                    }
                }
            }
            .padding(.vertical, 4)

            // Show detected categories and matching POIs
            if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                if !detectedCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Detected: \(detectedCategories.map { $0.displayName }.joined(separator: ", "))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        if !matchingPOIs.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Will notify at \(matchingPOIs.count) location\(matchingPOIs.count == 1 ? "" : "s"):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ForEach(matchingPOIs.prefix(5)) { poi in
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 10))
                                        Text(poi.name ?? "Unnamed")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                }

                                if matchingPOIs.count > 5 {
                                    Text("... and \(matchingPOIs.count - 5) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                            .padding(.leading, 20)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("No matching locations saved. Add some points of interest to enable smart notifications.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            Button(action: { showingAddPOI = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Locations")
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                } else if isAnalyzing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Analyzing task...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text("Enter a task description to detect relevant locations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Distance picker for smart notifications
            if !matchingPOIs.isEmpty {
                Picker("Notification Distance", selection: $locationNotificationDistance) {
                    ForEach([10, 15, 25, 50, 100], id: \.self) { distance in
                        Text("\(distance) metres").tag(distance)
                    }
                }
            }
        }
    }

    // MARK: - Smart Notification Analysis

    private func analyzeTaskForSmartNotification() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        // Skip if already analyzed this exact title
        guard trimmedTitle != lastAnalyzedTitle else { return }

        // Cancel any pending analysis task
        analysisTask?.cancel()
        analysisTask = nil

        guard !trimmedTitle.isEmpty else {
            detectedCategories = []
            matchingPOIs = []
            isAnalyzing = false
            lastAnalyzedTitle = ""
            return
        }

        // Capture the context for thread-safe access
        let context = viewContext

        // Use async analysis if Apple Intelligence is available
        if SmartTaskAnalyzer.shared.isAppleIntelligenceAvailable {
            isAnalyzing = true
            let titleToAnalyze = trimmedTitle

            analysisTask = Task { @MainActor in
                // Add small delay for debouncing (prevents too many API calls while typing)
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

                // Check if task was cancelled during sleep
                guard !Task.isCancelled else {
                    return
                }

                // Verify title hasn't changed during delay
                guard titleToAnalyze == title.trimmingCharacters(in: .whitespaces) else {
                    return
                }

                let categories = await SmartTaskAnalyzer.shared.analyzeTaskAllCategories(title: titleToAnalyze)

                // Check cancellation again after async call
                guard !Task.isCancelled else {
                    return
                }

                detectedCategories = categories
                if !categories.isEmpty {
                    matchingPOIs = SmartTaskAnalyzer.shared.findMatchingPOIs(for: categories, in: context)
                } else {
                    matchingPOIs = []
                }
                lastAnalyzedTitle = titleToAnalyze
                isAnalyzing = false
            }
        } else {
            // Synchronous keyword-based analysis
            detectedCategories = TaskCategoryAnalyzer.analyzeTask(title: trimmedTitle)
            if !detectedCategories.isEmpty {
                matchingPOIs = TaskCategoryAnalyzer.findMatchingPOIs(for: detectedCategories, in: context)
            } else {
                matchingPOIs = []
            }
            lastAnalyzedTitle = trimmedTitle
        }
    }
}

