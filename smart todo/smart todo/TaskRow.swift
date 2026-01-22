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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title ?? "Untitled Task")
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                    .font(.body)

                // Display notification information based on type
                if isLocationBased {
                    // Location-based notification
                    locationNotificationInfo
                } else {
                    // Time-based notification - show due date
                    if let dueDate = task.dueDate {
                        timeBasedNotificationInfo(dueDate: dueDate)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isOverdue() ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    @ViewBuilder
    private var locationNotificationInfo: some View {
        if let poi = task.notificationLocation {
            let distance = Int(task.locationNotificationDistance)
            let locationName = poi.name ?? "Unknown location"

            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Notify when \(distance) metre\(distance == 1 ? "" : "s") from \(locationName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "location.slash")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Location notification (no location set)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    @ViewBuilder
    private func timeBasedNotificationInfo(dueDate: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption)
            Text("Due: \(formatDate(dueDate))")
                .font(.caption)
                .foregroundColor(isOverdue(dueDate) ? .red : .secondary)

            if isOverdue(dueDate) {
                Text("OVERDUE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(4)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !task.isCompleted
    }

    private func isOverdue() -> Bool {
        // Only time-based notifications can be overdue
        guard !isLocationBased else { return false }

        if let dueDate = task.dueDate {
            return isOverdue(dueDate)
        }
        return false
    }
}

