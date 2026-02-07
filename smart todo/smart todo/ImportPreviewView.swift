//
//  ImportPreviewView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 7/2/2026.
//

import SwiftUI

/// Row component for showing analyzed import item with category, POIs, and notification type
struct ImportPreviewRow: View {
    @Binding var item: ImportableItem
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row content
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 14) {
                    // Source icon
                    ZStack {
                        Circle()
                            .fill(sourceColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: item.sourceType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(sourceColor)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        // Title
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 1)

                        // Category and POI badges
                        HStack(spacing: 8) {
                            if let category = item.primaryCategory {
                                categoryBadge(category: category)
                            }

                            if item.matchingPOICount > 0 {
                                poiBadge(count: item.matchingPOICount)
                            }

                            if item.dueDate != nil {
                                dateBadge
                            }
                        }
                    }

                    Spacer()

                    // Notification type indicator
                    notificationTypeIndicator

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                expandedContent
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Computed Properties

    private var sourceColor: Color {
        item.sourceType == .calendar ? .red : .blue
    }

    // MARK: - Badge Components

    private func categoryBadge(category: LocationCategory) -> some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 10))
            Text(category.singularDisplayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.12))
        .cornerRadius(6)
    }

    private func poiBadge(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 10))
            Text("\(count) POI\(count == 1 ? "" : "s")")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.12))
        .cornerRadius(6)
    }

    private var dateBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
            Text("Due")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(6)
    }

    private var notificationTypeIndicator: some View {
        ZStack {
            Circle()
                .fill(notificationTypeColor.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: item.suggestedNotificationType.icon)
                .font(.system(size: 14))
                .foregroundColor(notificationTypeColor)
        }
    }

    private var notificationTypeColor: Color {
        switch item.suggestedNotificationType {
        case .time: return .orange
        case .smart: return .purple
        case .location: return .green
        case .manual: return .gray
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            // Date info
            if let dateText = item.dateDisplayText {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(dateText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Notes preview
            if let notes = item.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }

            // Detected categories
            if !item.detectedCategories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Categories")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.detectedCategories, id: \.rawValue) { category in
                                categoryBadge(category: category)
                            }
                        }
                        .padding(.leading, 28)
                    }
                }
            }

            // Matching POIs
            if !item.matchingPOIs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Matching Locations")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.matchingPOIs.prefix(3), id: \.id) { poi in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text(poi.name ?? "Unknown")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.leading, 28)
                        }

                        if item.matchingPOIs.count > 3 {
                            Text("+ \(item.matchingPOIs.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                }
            }

            // Notification type picker
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("Notification Type")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                notificationTypePicker
                    .padding(.leading, 28)
            }

            // Reason text
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                    .frame(width: 20)
                Text(item.notificationReasonText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.bottom, 8)
    }

    private var notificationTypePicker: some View {
        HStack(spacing: 8) {
            ForEach(SuggestedNotificationType.allCases, id: \.rawValue) { type in
                Button(action: {
                    item.suggestedNotificationType = type
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 16))
                        Text(type.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(item.suggestedNotificationType == type ? .white : typeColor(for: type))
                    .frame(width: 70, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.suggestedNotificationType == type ? typeColor(for: type) : typeColor(for: type).opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func typeColor(for type: SuggestedNotificationType) -> Color {
        switch type {
        case .time: return .orange
        case .smart: return .purple
        case .location: return .green
        case .manual: return .gray
        }
    }
}

// MARK: - Standalone Preview Row (for use outside of list)

struct ImportPreviewCard: View {
    @Binding var item: ImportableItem

    var body: some View {
        ImportPreviewRow(item: $item)
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    List {
        ImportPreviewRow(item: .constant(ImportableItem(
            id: "1",
            title: "Buy groceries from the supermarket",
            notes: "Need milk, bread, eggs, and vegetables for the week",
            dueDate: Date().addingTimeInterval(86400),
            sourceType: .reminder,
            originalIdentifier: "1",
            detectedCategories: [.supermarket, .grocery],
            matchingPOIs: [],
            suggestedNotificationType: .smart,
            isSelected: true,
            isAlreadyImported: false
        )))

        ImportPreviewRow(item: .constant(ImportableItem(
            id: "2",
            title: "Pick up prescription",
            notes: nil,
            dueDate: nil,
            sourceType: .calendar,
            originalIdentifier: "2",
            detectedCategories: [.pharmacy],
            matchingPOIs: [],
            suggestedNotificationType: .smart,
            isSelected: true,
            isAlreadyImported: false
        )))

        ImportPreviewRow(item: .constant(ImportableItem(
            id: "3",
            title: "Team meeting",
            notes: "Discuss Q1 results",
            dueDate: Date().addingTimeInterval(3600),
            sourceType: .calendar,
            originalIdentifier: "3",
            detectedCategories: [],
            matchingPOIs: [],
            suggestedNotificationType: .time,
            isSelected: true,
            isAlreadyImported: false
        )))
    }
    .listStyle(InsetGroupedListStyle())
}
