//
//  TaskRow.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData

struct TaskRow: View {
    let task: TodoTask
    let onToggleComplete: () -> Void

    private var isLocationBased: Bool {
        task.notificationType == "location"
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
        HStack(alignment: .center, spacing: 14) {
            // Checkbox button
            Button(action: onToggleComplete) {
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

            // Task content
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title ?? "Untitled Task")
                    .font(.system(size: 16, weight: task.isCompleted ? .regular : .medium))
                    .strikethrough(task.isCompleted, color: .gray)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                if isLocationBased {
                    locationNotificationInfo
                } else if let dueDate = task.dueDate {
                    timeBasedNotificationInfo(dueDate: dueDate)
                }
            }

            Spacer()

            // Notification type indicator
            notificationTypeIndicator
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title ?? "Untitled Task"), \(task.isCompleted ? "completed" : "pending")")
    }

    // MARK: - Notification Type Indicator

    @ViewBuilder
    private var notificationTypeIndicator: some View {
        if isLocationBased {
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

                Text("•")
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
        let now = Date()

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
        guard !isLocationBased else { return false }
        if let dueDate = task.dueDate {
            return isOverdue(dueDate)
        }
        return false
    }
}

