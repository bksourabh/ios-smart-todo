//
//  TaskRow.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

struct TaskRow: View {
    @ObservedObject var task: TodoTask
    let onToggleComplete: () -> Void
    var onTapTask: (() -> Void)? = nil
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showSubTasks = false
    @State private var subTaskRefresh = 0

    private var isLocationBased: Bool {
        task.notificationType == "location"
    }

    private var isSmartBased: Bool {
        task.notificationType == "smart"
    }

    private var sortedSubTasks: [SubTask] {
        guard let subTasks = task.subTasks as? Set<SubTask> else { return [] }
        return subTasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var hasSubTasks: Bool {
        !sortedSubTasks.isEmpty
    }

    private var subTaskProgress: String {
        let all = sortedSubTasks
        let completed = all.filter { $0.isCompleted }
        return "\(completed.count)/\(all.count)"
    }

    private var cardBackgroundColor: Color {
        if task.isCompleted {
            return Color(UIColor.secondarySystemBackground)
        } else if isOverdue() {
            return Color.red.opacity(0.08)
        } else {
            return Color(UIColor.secondarySystemBackground)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main task header area
            mainTaskRow

            // Subtasks expandable section
            if hasSubTasks && showSubTasks {
                subTasksList
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(cardBackgroundColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isOverdue() && !task.isCompleted ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(task.title ?? "Untitled Task"), \(task.isCompleted ? "completed" : "pending")")
    }

    // MARK: - Main Task Row

    private var mainTaskRow: some View {
        HStack(alignment: .center, spacing: 14) {
            // Checkbox button
            Button {
                onToggleComplete()
            } label: {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? Color.green : (isOverdue() ? Color.red : Color.gray.opacity(0.4)), lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if task.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 26, height: 26)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(task.isCompleted ? "Mark as incomplete" : "Mark as complete")

            // Task content — tapping this opens edit
            taskContentArea
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapTask?()
                }

            // Notification type indicator
            notificationTypeIndicator
        }
    }

    // MARK: - Task Content Area

    private var taskContentArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title ?? "Untitled Task")
                .font(.system(size: 16, weight: task.isCompleted ? .regular : .medium))
                .strikethrough(task.isCompleted, color: .gray)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .lineLimit(2)

            if hasSubTasks {
                subTaskSummary
            } else if isSmartBased {
                smartNotificationInfo
            } else if isLocationBased {
                locationNotificationInfo
            } else if let dueDate = task.dueDate {
                timeBasedNotificationInfo(dueDate: dueDate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - SubTask Summary (progress + expand chevron)

    private var subTaskSummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 12))
                .foregroundColor(.blue)
            Text(subTaskProgress)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSubTasks.toggle()
                }
            } label: {
                Image(systemName: showSubTasks ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - SubTasks List

    private var subTasksList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, 0)
                .padding(.vertical, 8)

            ForEach(sortedSubTasks, id: \.id) { subTask in
                HStack(spacing: 10) {
                    Button {
                        toggleSubTask(subTask)
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(subTask.isCompleted ? Color.green : Color.gray.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 20, height: 20)

                            if subTask.isCompleted {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 20, height: 20)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .contentShape(Circle().inset(by: -8))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text(subTask.title ?? "")
                        .font(.system(size: 14))
                        .strikethrough(subTask.isCompleted, color: .gray)
                        .foregroundColor(subTask.isCompleted ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.leading, 26)
                .padding(.vertical, 6)
            }
        }
        .padding(.bottom, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .id(subTaskRefresh)
    }

    // MARK: - Notification Type Indicator

    @ViewBuilder
    private var notificationTypeIndicator: some View {
        if isSmartBased {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14))
                .foregroundColor(.purple)
                .padding(8)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
        } else if isLocationBased {
            Image(systemName: "location.fill")
                .font(.system(size: 14))
                .foregroundColor(.purple)
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .clipShape(Circle())
        } else if task.notificationMinutes > 0 {
            Image(systemName: "bell.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(Circle())
        }
    }

    // MARK: - Smart Notification Info

    @ViewBuilder
    private var smartNotificationInfo: some View {
        let distance = Int(task.locationNotificationDistance)
        let categoryName: String = {
            if let categoryRawValue = task.smartLocationCategory,
               let category = LocationCategory(rawValue: categoryRawValue) {
                return category.displayName
            }
            return "nearby locations"
        }()

        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12))
                .foregroundColor(.purple)

            Text("When \(distance)m from \(categoryName)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Location Notification Info

    @ViewBuilder
    private var locationNotificationInfo: some View {
        if let poi = task.notificationLocation {
            let distance = Int(task.locationNotificationDistance)
            let locationName = poi.name ?? "Unknown"

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.purple)

                Text("\(distance)m from \(locationName)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "location.slash")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text("No location set")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Time-Based Notification Info

    @ViewBuilder
    private func timeBasedNotificationInfo(dueDate: Date) -> some View {
        HStack(spacing: 6) {
            if isOverdue(dueDate) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)

                Text("Overdue")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)

                Text("\u{2022}")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Text(formatRelativeDate(dueDate))
                .font(.system(size: 13))
                .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
        }
    }

    // MARK: - Helpers

    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !task.isCompleted
    }

    private func isOverdue() -> Bool {
        guard !isLocationBased && !isSmartBased else { return false }
        if let dueDate = task.dueDate {
            return isOverdue(dueDate)
        }
        return false
    }

    private func toggleSubTask(_ subTask: SubTask) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        subTask.isCompleted.toggle()

        // Auto-complete parent if all subtasks are done
        let allDone = sortedSubTasks.allSatisfy { $0.isCompleted }
        if allDone && !task.isCompleted {
            task.isCompleted = true
            onToggleComplete()
        }

        do {
            try viewContext.save()
        } catch {
            print("Error saving subtask toggle: \(error)")
        }

        // Force refresh the subtasks UI
        subTaskRefresh += 1
    }
}
