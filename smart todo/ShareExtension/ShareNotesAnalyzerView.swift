//
//  ShareNotesAnalyzerView.swift
//  ShareExtension
//
//  Created by Sourabh Mazumder on 8/3/2026.
//

import SwiftUI

struct ShareNotesAnalyzerView: View {
    let sharedText: String
    let onDismiss: () -> Void

    enum Step {
        case analyzing
        case review
        case importing
        case done
        case error(String)
    }

    @State private var currentStep: Step = .analyzing
    @State private var parsedItems: [String] = []
    @State private var taskGroups: [ShareTaskGroup] = []
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var importedCount = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                stepContent
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isImporting {
                        Button("Cancel") {
                            onDismiss()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            analyzeText()
        }
    }

    private var isImporting: Bool {
        if case .importing = currentStep { return true }
        return false
    }

    private var navigationTitle: String {
        switch currentStep {
        case .analyzing: return "Analyzing"
        case .review: return "Review Groups"
        case .importing: return "Importing"
        case .done: return "Done"
        case .error: return "Error"
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .analyzing:
            analyzingView
        case .review:
            reviewView
        case .importing:
            importingView
        case .done:
            doneView
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.orange)
            }

            VStack(spacing: 8) {
                Text("Analyzing your notes...")
                    .font(.headline)
                Text("Grouping items by location")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Review

    private var reviewView: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(taskGroups.count) group\(taskGroups.count == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(parsedItems.count) items total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: toggleSelectAll) {
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
                        ShareGroupCard(
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
                    Text("Analyze & Import \(selectedGroupIDs.count) Group\(selectedGroupIDs.count == 1 ? "" : "s")")
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

    // MARK: - Importing

    private var importingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)

            Text("Saving tasks...")
                .font(.headline)

            Spacer()
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.green)
            }

            VStack(spacing: 8) {
                Text("Import Complete!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(importedCount) task\(importedCount == 1 ? "" : "s") with subtasks saved")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 14))
                    Text("Open Smart Todo to view your tasks")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }

            Button(action: { onDismiss() }) {
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

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                currentStep = .analyzing
                analyzeText()
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") {
                onDismiss()
            }
            .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Actions

    private func analyzeText() {
        parsedItems = NotesTextParser.parseItems(from: sharedText)

        guard !parsedItems.isEmpty else {
            currentStep = .error("No items found in the shared text.")
            return
        }

        // Small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            taskGroups = ShareTaskGroup.groupByKeywords(parsedItems)
            selectedGroupIDs = Set(taskGroups.map { $0.id })
            withAnimation {
                currentStep = .review
            }
        }
    }

    private func toggleSelectAll() {
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

        let importData = SharedImportData(groups: groupsToImport, timestamp: Date())
        let saved = SharedStorage.saveImportData(importData)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if saved {
                importedCount = groupsToImport.count
                withAnimation {
                    currentStep = .done
                }
            } else {
                withAnimation {
                    currentStep = .error("Failed to save tasks. Please try again.")
                }
            }
        }
    }
}

// MARK: - Group Card

struct ShareGroupCard: View {
    let group: ShareTaskGroup
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
