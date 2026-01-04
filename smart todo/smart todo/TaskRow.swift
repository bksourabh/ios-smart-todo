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
                
                // Display date information
                if let dateType = task.dateType {
                    if dateType == "dueDate", let dueDate = task.dueDate {
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
                    } else if dateType == "toBeDoneIn", let startDate = task.startDate, let endDate = task.endDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("\(formatDate(startDate)) - \(formatDate(endDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if isOverdue(endDate) {
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
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isOverdue() ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(8)
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
        if let dateType = task.dateType {
            if dateType == "dueDate", let dueDate = task.dueDate {
                return isOverdue(dueDate)
            } else if dateType == "toBeDoneIn", let endDate = task.endDate {
                return isOverdue(endDate)
            }
        }
        return false
    }
}

