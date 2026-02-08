//
//  CalendarImportView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 7/2/2026.
//

import SwiftUI
import EventKit
import CoreData
import UIKit

/// Multi-step import flow for Calendar events and Reminders
struct CalendarImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager

    @ObservedObject private var eventKitManager = EventKitManager.shared

    // MARK: - State

    enum ImportStep: Int, CaseIterable {
        case permissions = 0
        case sourceSelection = 1
        case itemSelection = 2
        case analysisPreview = 3
        case importing = 4
    }

    @State private var currentStep: ImportStep = .permissions
    @State private var importFromCalendar = true
    @State private var importFromReminders = true
    @State private var dateRangeStart = Date()
    @State private var dateRangeEnd = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var items: [ImportableItem] = []
    @State private var isLoading = false
    @State private var isAnalyzing = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importedCount = 0
    @State private var importError: String?
    @State private var analysisProgress: Double = 0
    @State private var selectionVersion: Int = 0  // Used to force List refresh

    // MARK: - Computed Properties

    private var selectedItems: [ImportableItem] {
        items.filter { $0.isSelected }
    }

    private var canProceedFromPermissions: Bool {
        eventKitManager.isCalendarAuthorized || eventKitManager.isReminderAuthorized
    }

    private var canProceedFromSourceSelection: Bool {
        (importFromCalendar && eventKitManager.isCalendarAuthorized) ||
        (importFromReminders && eventKitManager.isReminderAuthorized)
    }

    private var stepTitle: String {
        switch currentStep {
        case .permissions: return "Permissions"
        case .sourceSelection: return "Select Sources"
        case .itemSelection: return "Select Items"
        case .analysisPreview: return "Review"
        case .importing: return "Import"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Content based on current step
                contentForCurrentStep
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != .importing {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentStep.rawValue > 0 && currentStep != .importing {
                        Button("Back") {
                            withAnimation {
                                goToPreviousStep()
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            eventKitManager.checkAuthorizationStatus()
            // Auto-advance if already authorized
            if canProceedFromPermissions && currentStep == .permissions {
                currentStep = .sourceSelection
            }
        }
    }

    @ViewBuilder
    private var contentForCurrentStep: some View {
        switch currentStep {
        case .permissions:
            permissionsContent
        case .sourceSelection:
            sourceSelectionContent
        case .itemSelection:
            itemSelectionContent
        case .analysisPreview:
            analysisPreviewContent
        case .importing:
            importingContent
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(ImportStep.allCases, id: \.rawValue) { step in
                if step != .importing {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: step.rawValue == currentStep.rawValue ? 12 : 8,
                               height: step.rawValue == currentStep.rawValue ? 12 : 8)
                        .scaleEffect(step.rawValue == currentStep.rawValue ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Permissions Content

    private var permissionsContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 44))
                                .foregroundColor(.blue)
                        }

                        Text("Access Your Calendar & Reminders")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Grant access to import your existing events and reminders into Smart Todo.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 40)

                    // Permission cards
                    VStack(spacing: 16) {
                        permissionCard(
                            title: "Calendar",
                            icon: "calendar",
                            color: .red,
                            isAuthorized: eventKitManager.isCalendarAuthorized,
                            status: calendarStatusText,
                            action: requestCalendarAccess
                        )

                        permissionCard(
                            title: "Reminders",
                            icon: "list.bullet",
                            color: .blue,
                            isAuthorized: eventKitManager.isReminderAuthorized,
                            status: reminderStatusText,
                            action: requestReminderAccess
                        )
                    }
                    .padding(.horizontal, 24)

                    // Privacy note
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.green)
                        Text("Your data stays on your device and is never shared.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }

            // Bottom buttons
            VStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        currentStep = .sourceSelection
                    }
                }) {
                    HStack {
                        Text("Continue")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canProceedFromPermissions ? Color.blue : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(!canProceedFromPermissions)

                Button("Skip for Now") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
        }
    }

    private func permissionCard(
        title: String,
        icon: String,
        color: Color,
        isAuthorized: Bool,
        status: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundColor(isAuthorized ? .green : .orange)
            }

            Spacer()

            if isAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 24))
            } else {
                Button("Enable") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var calendarStatusText: String {
        if eventKitManager.isCalendarAuthorized {
            return "Access granted"
        } else if eventKitManager.calendarAuthorizationStatus == .denied {
            return "Denied - enable in Settings"
        } else {
            return "Not set up"
        }
    }

    private var reminderStatusText: String {
        if eventKitManager.isReminderAuthorized {
            return "Access granted"
        } else if eventKitManager.reminderAuthorizationStatus == .denied {
            return "Denied - enable in Settings"
        } else {
            return "Not set up"
        }
    }

    private func requestCalendarAccess() {
        Task {
            _ = await eventKitManager.requestCalendarAccess()
        }
    }

    private func requestReminderAccess() {
        Task {
            _ = await eventKitManager.requestReminderAccess()
        }
    }

    // MARK: - Source Selection Content

    private var sourceSelectionContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Choose What to Import")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Select the sources and date range for importing items.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 24)

                    // Source toggles
                    VStack(spacing: 16) {
                        if eventKitManager.isCalendarAuthorized {
                            sourceToggle(
                                title: "Calendar Events",
                                icon: "calendar",
                                color: .red,
                                isOn: $importFromCalendar,
                                subtitle: "Import upcoming calendar events"
                            )
                        }

                        if eventKitManager.isReminderAuthorized {
                            sourceToggle(
                                title: "Reminders",
                                icon: "list.bullet",
                                color: .blue,
                                isOn: $importFromReminders,
                                subtitle: "Import incomplete reminders"
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    // Date range picker (only for calendar events)
                    if importFromCalendar && eventKitManager.isCalendarAuthorized {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Date Range")
                                .font(.headline)
                                .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                DatePicker("From", selection: $dateRangeStart, displayedComponents: .date)
                                DatePicker("To", selection: $dateRangeEnd, in: dateRangeStart..., displayedComponents: .date)
                            }
                            .padding(.horizontal, 24)

                            // Quick date range buttons
                            HStack(spacing: 12) {
                                dateRangeButton(title: "7 days", days: 7)
                                dateRangeButton(title: "14 days", days: 14)
                                dateRangeButton(title: "30 days", days: 30)
                                dateRangeButton(title: "90 days", days: 90)
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 8)
                    }
                }
            }

            // Bottom buttons
            VStack(spacing: 12) {
                Button(action: {
                    fetchItems()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Fetch Items")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canProceedFromSourceSelection && !isLoading ? Color.blue : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(!canProceedFromSourceSelection || isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
        }
    }

    private func sourceToggle(
        title: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>,
        subtitle: String
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: color))
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func dateRangeButton(title: String, days: Int) -> some View {
        Button(action: {
            dateRangeEnd = Calendar.current.date(byAdding: .day, value: days, to: dateRangeStart) ?? dateRangeStart
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func fetchItems() {
        isLoading = true
        items = []

        Task {
            var fetchedItems: [ImportableItem] = []
            let importedCalendarIds = eventKitManager.getImportedCalendarEventIdentifiers()
            let importedReminderIds = eventKitManager.getImportedReminderIdentifiers()

            // Fetch calendar events
            if importFromCalendar && eventKitManager.isCalendarAuthorized {
                let events = eventKitManager.fetchCalendarEvents(from: dateRangeStart, to: dateRangeEnd)
                for event in events {
                    let identifier = event.eventIdentifier ?? eventKitManager.generateFallbackIdentifier(
                        title: event.title ?? "",
                        date: event.startDate
                    )
                    let isAlreadyImported = importedCalendarIds.contains(identifier)
                    let item = ImportableItem(from: event, isAlreadyImported: isAlreadyImported)
                    fetchedItems.append(item)
                }
            }

            // Fetch reminders
            if importFromReminders && eventKitManager.isReminderAuthorized {
                let reminders = await eventKitManager.fetchReminders()
                for reminder in reminders {
                    let isAlreadyImported = importedReminderIds.contains(reminder.calendarItemIdentifier)
                    let item = ImportableItem(from: reminder, isAlreadyImported: isAlreadyImported)
                    fetchedItems.append(item)
                }
            }

            await MainActor.run {
                items = fetchedItems
                isLoading = false
                withAnimation {
                    currentStep = .itemSelection
                }
            }
        }
    }

    // MARK: - Item Selection Content

    // Computed properties for filtered items
    private var calendarItems: [ImportableItem] {
        items.filter { $0.sourceType == .calendar }
    }

    private var reminderItems: [ImportableItem] {
        items.filter { $0.sourceType == .reminder }
    }

    private var itemSelectionContent: some View {
        VStack(spacing: 0) {
            // Header with counts
            VStack(spacing: 8) {
                Text("Select Items to Import")
                    .font(.title3)
                    .fontWeight(.bold)

                HStack(spacing: 16) {
                    Text("\(items.count) items found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(selectedItems.count) selected")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 16)

            // Select/Deselect all
            HStack {
                Button(action: selectAllItems) {
                    Text("Select All")
                        .font(.subheadline)
                }

                Spacer()

                Button(action: deselectAllItems) {
                    Text("Deselect All")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            // Items list grouped by source
            if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No items found")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Try adjusting your date range or sources.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Calendar events section
                    if !calendarItems.isEmpty {
                        Section(header: Text("Calendar Events (\(calendarItems.count))")) {
                            ForEach(calendarItems, id: \.id) { item in
                                ImportItemRowStateless(
                                    item: item,
                                    onToggle: { toggleItem(id: item.id) }
                                )
                            }
                        }
                    }

                    // Reminders section
                    if !reminderItems.isEmpty {
                        Section(header: Text("Reminders (\(reminderItems.count))")) {
                            ForEach(reminderItems, id: \.id) { item in
                                ImportItemRowStateless(
                                    item: item,
                                    onToggle: { toggleItem(id: item.id) }
                                )
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .id(selectionVersion)  // Force refresh when selection changes
            }

            // Bottom buttons
            VStack(spacing: 12) {
                Button(action: {
                    analyzeItems()
                }) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Analyzing...")
                        } else {
                            Text("Analyze \(selectedItems.count) Items")
                            Image(systemName: "sparkles")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(!selectedItems.isEmpty && !isAnalyzing ? Color.blue : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(selectedItems.isEmpty || isAnalyzing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
        }
    }

    private func toggleItem(id: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            var updatedItems = items
            updatedItems[index].isSelected.toggle()
            items = updatedItems
            selectionVersion += 1  // Force List to refresh
        }
    }

    private func selectAllItems() {
        items = items.map { item in
            var updated = item
            updated.isSelected = true
            return updated
        }
        selectionVersion += 1  // Force List to refresh
    }

    private func deselectAllItems() {
        items = items.map { item in
            var updated = item
            updated.isSelected = false
            return updated
        }
        selectionVersion += 1  // Force List to refresh
    }

    private func analyzeItems() {
        isAnalyzing = true
        analysisProgress = 0

        Task {
            let selectedItemsToAnalyze = selectedItems
            let analyzer = SmartTaskAnalyzer.shared

            let analyzedItems = await analyzer.analyzeItemsForImport(selectedItemsToAnalyze, in: viewContext)

            await MainActor.run {
                // Update items with analysis results
                for analyzedItem in analyzedItems {
                    if let index = items.firstIndex(where: { $0.id == analyzedItem.id }) {
                        items[index] = analyzedItem
                    }
                }

                isAnalyzing = false
                withAnimation {
                    currentStep = .analysisPreview
                }
            }
        }
    }

    // MARK: - Analysis Preview Content

    private var analysisPreviewContent: some View {
        VStack(spacing: 0) {
            // Header with summary
            VStack(spacing: 12) {
                Text("Review & Import")
                    .font(.title3)
                    .fontWeight(.bold)

                // Summary stats
                HStack(spacing: 24) {
                    summaryStatView(
                        value: "\(selectedItems.count)",
                        label: "Items",
                        icon: "doc.text.fill",
                        color: .blue
                    )

                    summaryStatView(
                        value: "\(selectedItems.filter { !$0.detectedCategories.isEmpty }.count)",
                        label: "Categorized",
                        icon: "tag.fill",
                        color: .purple
                    )

                    summaryStatView(
                        value: "\(selectedItems.filter { !$0.matchingPOIs.isEmpty }.count)",
                        label: "With POIs",
                        icon: "mappin.circle.fill",
                        color: .green
                    )
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)

            // Analyzed items list
            List {
                ForEach(selectedItems.indices, id: \.self) { index in
                    let globalIndex = items.firstIndex(where: { $0.id == selectedItems[index].id })!
                    ImportPreviewRow(item: $items[globalIndex])
                }
            }
            .listStyle(InsetGroupedListStyle())

            // Bottom buttons
            VStack(spacing: 12) {
                Button(action: {
                    performImport()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import \(selectedItems.count) Items")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(14)
                    .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
        }
    }

    private func summaryStatView(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Importing Content

    private var importingContent: some View {
        VStack(spacing: 32) {
            Spacer()

            if isImporting {
                // Progress view
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 100, height: 100)
                        Circle()
                            .trim(from: 0, to: importProgress)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear, value: importProgress)
                        Text("\(Int(importProgress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Text("Importing items...")
                        .font(.headline)

                    Text("\(importedCount) of \(selectedItems.count) imported")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let error = importError {
                // Error view
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                    }

                    Text("Import Failed")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button("Try Again") {
                        performImport()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Success view
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                    }

                    Text("Import Complete!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(importedCount) items imported successfully")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                }
            }

            Spacer()
        }
    }

    private func performImport() {
        isImporting = true
        importProgress = 0
        importedCount = 0
        importError = nil
        currentStep = .importing

        Task {
            do {
                let itemsToImport = selectedItems
                var calendarIds: [String] = []
                var reminderIds: [String] = []

                for (index, item) in itemsToImport.enumerated() {
                    // Create TodoTask
                    let task = TodoTask(context: viewContext)
                    task.id = UUID()
                    task.title = item.title
                    task.isCompleted = false
                    task.createdAt = Date()

                    // Set date type and dates
                    if let dueDate = item.dueDate {
                        task.dateType = "dueDate"
                        task.dueDate = dueDate
                        task.notificationMinutes = 15 // Default 15 minutes before
                    } else {
                        task.dateType = "none"
                    }

                    // Set notification type
                    switch item.suggestedNotificationType {
                    case .time:
                        task.notificationType = "time"
                    case .smart:
                        task.notificationType = "smart"
                        if let category = item.primaryCategory {
                            task.smartLocationCategory = category.rawValue
                        }
                    case .location:
                        task.notificationType = "location"
                        if let firstPOI = item.matchingPOIs.first {
                            task.notificationLocation = firstPOI
                        }
                    case .manual:
                        task.notificationType = "time"
                    }

                    task.locationNotificationDistance = 100 // Default distance

                    // Track imported identifiers
                    if item.sourceType == .calendar {
                        calendarIds.append(item.originalIdentifier)
                    } else {
                        reminderIds.append(item.originalIdentifier)
                    }

                    // Update progress
                    await MainActor.run {
                        importedCount = index + 1
                        importProgress = Double(index + 1) / Double(itemsToImport.count)
                    }
                }

                // Save context
                try viewContext.save()

                // Mark items as imported
                eventKitManager.markCalendarEventsAsImported(calendarIds)
                eventKitManager.markRemindersAsImported(reminderIds)

                // Schedule notifications for imported tasks
                notificationManager.scheduleNotificationsForTodayTasks(context: viewContext)
                if LocationManager.shared.isLocationBasedNotificationsAvailable {
                    notificationManager.setupLocationMonitoringForAllTasks(context: viewContext)
                }

                await MainActor.run {
                    isImporting = false
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }

            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Navigation

    private func goToPreviousStep() {
        switch currentStep {
        case .permissions:
            break
        case .sourceSelection:
            currentStep = .permissions
        case .itemSelection:
            currentStep = .sourceSelection
        case .analysisPreview:
            currentStep = .itemSelection
        case .importing:
            break
        }
    }
}

// MARK: - Import Item Row (Stateless version for proper UI updates)

struct ImportItemRowStateless: View {
    let item: ImportableItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Selection checkbox
                ZStack {
                    Circle()
                        .stroke(item.isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if item.isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Source icon
                ZStack {
                    Circle()
                        .fill(item.sourceType == .calendar ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: item.sourceType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(item.sourceType == .calendar ? .red : .blue)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        if item.isAlreadyImported {
                            Text("Imported")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }

                    if let dateText = item.dateDisplayText {
                        Text(dateText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Import Item Row (Binding version for preview)

struct ImportItemRow: View {
    @Binding var item: ImportableItem

    var body: some View {
        ImportItemRowStateless(item: item, onToggle: { item.isSelected.toggle() })
    }
}

// MARK: - Calendar Import Setup View (for initial setup flow)

struct CalendarImportSetupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var notificationManager: NotificationManager
    @Binding var isSetupComplete: Bool

    @ObservedObject private var eventKitManager = EventKitManager.shared

    @State private var showingImportFlow = false
    @State private var hasCompletedImport = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 160, height: 160)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                }

                Text("Import Your Calendar & Reminders")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Bring in your existing calendar events and reminders. Our AI will automatically categorize them for smart location-based notifications.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Features
            VStack(spacing: 16) {
                featureRow(
                    icon: "calendar",
                    color: .red,
                    title: "Calendar Events",
                    description: "Import upcoming events from your calendar"
                )

                featureRow(
                    icon: "list.bullet",
                    color: .blue,
                    title: "Reminders",
                    description: "Import incomplete reminders as tasks"
                )

                featureRow(
                    icon: "sparkles",
                    color: .purple,
                    title: "AI Categorization",
                    description: "Automatically detect categories for smart notifications"
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Bottom buttons
            VStack(spacing: 12) {
                Button(action: {
                    showingImportFlow = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Now")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(14)
                    .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                }

                Button(action: {
                    isSetupComplete = true
                }) {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showingImportFlow, onDismiss: {
            // When the sheet is dismissed, mark setup as complete
            isSetupComplete = true
        }) {
            CalendarImportView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(notificationManager)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarImportView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(NotificationManager.shared)
}

#Preview("Setup View") {
    CalendarImportSetupView(isSetupComplete: .constant(false))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(NotificationManager.shared)
}
