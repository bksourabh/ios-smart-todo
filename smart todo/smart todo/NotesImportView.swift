//
//  NotesImportView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 8/3/2026.
//

import SwiftUI
import CoreData

/// Multi-step import flow for importing tasks from Notes
struct NotesImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager

    // MARK: - State

    enum ImportStep: Int, CaseIterable {
        case input = 0
        case analysis = 1
        case review = 2
        case importing = 3
    }

    @State private var currentStep: ImportStep = .input
    @State private var notesText: String = ""
    @State private var parsedItems: [String] = []
    @State private var taskGroups: [NotesTaskGroup] = []
    @State private var isAnalyzing = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importedCount = 0
    @State private var importError: String?

    // Track which groups/items user wants to import
    @State private var selectedGroupIDs: Set<UUID> = []

    private var stepTitle: String {
        switch currentStep {
        case .input: return "Paste Notes"
        case .analysis: return "Analyzing"
        case .review: return "Review Groups"
        case .importing: return "Import"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.top, 16)
                    .padding(.bottom, 8)

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
                    if currentStep == .review {
                        Button("Back") {
                            withAnimation {
                                currentStep = .input
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(isImporting)
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(ImportStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Content Router

    @ViewBuilder
    private var contentForCurrentStep: some View {
        switch currentStep {
        case .input:
            inputStepView
        case .analysis:
            analysisStepView
        case .review:
            reviewStepView
        case .importing:
            importingStepView
        }
    }

    // MARK: - Step 1: Input

    private var inputStepView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.title2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from Notes")
                            .font(.headline)
                        Text("Paste your notes content below. List items on separate lines or separated by commas.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("Apple Intelligence will group items by where they can be completed")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .padding(10)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.08), Color.blue.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Text editor
            ZStack(alignment: .topLeading) {
                if notesText.isEmpty {
                    Text("e.g.\nmilk\ntomatoes\nmedicines\nbread\nvitamins")
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $notesText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .scrollContentBackground(.hidden)
            }
            .frame(maxHeight: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)

            // Example hint
            VStack(alignment: .leading, spacing: 6) {
                Text("Tip: You can paste lists from Apple Notes, or type items separated by new lines or commas.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            // Analyze button
            Button(action: analyzeNotes) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    Text("Analyze & Group")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                .cornerRadius(14)
            }
            .disabled(notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Step 2: Analysis (loading)

    private var analysisStepView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.purple)
            }

            VStack(spacing: 8) {
                Text("Analyzing your notes...")
                    .font(.headline)

                Text("Grouping \(parsedItems.count) items by location")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "apple.intelligence")
                        .font(.system(size: 11))
                    Text("Powered by Apple Intelligence")
                        .font(.caption)
                }
                .foregroundColor(.purple)
                .padding(.top, 4)
            }

            Spacer()
        }
    }

    // MARK: - Step 3: Review Groups

    private var reviewStepView: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(taskGroups.count) group\(taskGroups.count == 1 ? "" : "s") created")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(parsedItems.count) items total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: selectAllGroups) {
                    Text(selectedGroupIDs.count == taskGroups.count ? "Deselect All" : "Select All")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))

            // Groups list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(taskGroups) { group in
                        NotesGroupCard(
                            group: group,
                            isSelected: selectedGroupIDs.contains(group.id),
                            onToggle: { toggleGroup(group.id) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            // Import button
            Button(action: importGroups) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import \(selectedGroupIDs.count) Group\(selectedGroupIDs.count == 1 ? "" : "s")")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedGroupIDs.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(14)
            }
            .disabled(selectedGroupIDs.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Step 4: Importing

    private var importingStepView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let error = importError {
                // Error state
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Import Error")
                    .font(.headline)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("Try Again") {
                    importError = nil
                    importGroups()
                }
                .buttonStyle(.borderedProminent)
            } else if isImporting {
                // Progress
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: importProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(importProgress * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Text("Importing tasks...")
                    .font(.headline)

                Text("\(importedCount) of \(selectedGroupIDs.count) groups imported")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Success
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Import Complete!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(importedCount) task\(importedCount == 1 ? "" : "s") with subtasks created")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { dismiss() }) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func analyzeNotes() {
        let text = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Parse items from text: split by newlines and commas, filter empties
        parsedItems = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet(charactersIn: "\n,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { line in
                // Strip common list prefixes: "- ", "* ", "1. ", "2) ", etc.
                var cleaned = line
                if let range = cleaned.range(of: #"^[\-\*\u2022]\s+"#, options: .regularExpression) {
                    cleaned = String(cleaned[range.upperBound...])
                }
                if let range = cleaned.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                    cleaned = String(cleaned[range.upperBound...])
                }
                // Strip checkbox prefixes like "[ ] " or "[x] "
                if let range = cleaned.range(of: #"^\[[ xX]?\]\s*"#, options: .regularExpression) {
                    cleaned = String(cleaned[range.upperBound...])
                }
                return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        guard !parsedItems.isEmpty else { return }

        withAnimation {
            currentStep = .analysis
        }

        isAnalyzing = true

        Task { @MainActor in
            taskGroups = await SmartTaskAnalyzer.shared.groupNotesItems(parsedItems)

            // Select all groups by default
            selectedGroupIDs = Set(taskGroups.map { $0.id })

            isAnalyzing = false

            withAnimation {
                currentStep = .review
            }
        }
    }

    private func selectAllGroups() {
        if selectedGroupIDs.count == taskGroups.count {
            selectedGroupIDs.removeAll()
        } else {
            selectedGroupIDs = Set(taskGroups.map { $0.id })
        }
    }

    private func toggleGroup(_ id: UUID) {
        if selectedGroupIDs.contains(id) {
            selectedGroupIDs.remove(id)
        } else {
            selectedGroupIDs.insert(id)
        }
    }

    private func importGroups() {
        let groupsToImport = taskGroups.filter { selectedGroupIDs.contains($0.id) }
        guard !groupsToImport.isEmpty else { return }

        withAnimation {
            currentStep = .importing
        }

        isImporting = true
        importedCount = 0
        importProgress = 0

        Task { @MainActor in
            let total = groupsToImport.count

            for (index, group) in groupsToImport.enumerated() {
                // Create parent task
                let todoTask = TodoTask(context: viewContext)
                todoTask.id = UUID()
                todoTask.title = group.groupTitle
                todoTask.isCompleted = false
                todoTask.createdAt = Date()
                todoTask.dateType = "smart"
                todoTask.notificationType = "smart"
                todoTask.locationNotificationDistance = 15

                if let category = group.locationCategory {
                    todoTask.smartLocationCategory = category.rawValue
                }

                // Create subtasks
                for (subIndex, itemTitle) in group.items.enumerated() {
                    let subTask = SubTask(context: viewContext)
                    subTask.id = UUID()
                    subTask.title = itemTitle
                    subTask.isCompleted = false
                    subTask.createdAt = Date()
                    subTask.sortOrder = Int16(subIndex)
                    subTask.parentTask = todoTask
                }

                importedCount = index + 1
                importProgress = Double(importedCount) / Double(total)
            }

            do {
                try viewContext.save()

                // Schedule smart notifications for imported tasks
                let fetchRequest: NSFetchRequest<TodoTask> = TodoTask.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "notificationType == %@", "smart")
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TodoTask.createdAt, ascending: false)]
                fetchRequest.fetchLimit = total

                if let recentTasks = try? viewContext.fetch(fetchRequest) {
                    for task in recentTasks {
                        if let categoryStr = task.smartLocationCategory,
                           let category = LocationCategory(rawValue: categoryStr) {
                            let matchingPOIs = TaskCategoryAnalyzer.findMatchingPOIs(for: [category], in: viewContext)
                            if !matchingPOIs.isEmpty {
                                notificationManager.scheduleSmartNotifications(for: task, matchingPOIs: matchingPOIs)
                            }
                        }
                    }
                }

                isImporting = false
            } catch {
                importError = "Failed to save tasks: \(error.localizedDescription)"
                isImporting = false
            }
        }
    }
}

// MARK: - Notes Group Card

struct NotesGroupCard: View {
    let group: NotesTaskGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                if let category = group.locationCategory {
                    Image(systemName: category.icon)
                        .foregroundColor(.purple)
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.groupTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .primary : .secondary)

                    if let category = group.locationCategory {
                        Text(category.singularDisplayName)
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }

                Spacer()

                Text("\(group.items.count) item\(group.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
            }

            // Subtask items
            VStack(alignment: .leading, spacing: 6) {
                ForEach(group.items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 18, height: 18)

                        Text(item)
                            .font(.system(size: 14))
                            .foregroundColor(isSelected ? .primary : .secondary)
                    }
                    .padding(.leading, 34)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .opacity(isSelected ? 1 : 0.7)
    }
}
