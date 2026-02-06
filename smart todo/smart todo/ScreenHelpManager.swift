//
//  ScreenHelpManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI

// MARK: - Screen Help Steps

enum ScreenType {
    case taskList
    case addEditTask
    case pointOfInterest
    case userProfile
}

struct HelpStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
}

struct ScreenHelpContent {
    let screenTitle: String
    let screenIcon: String
    let steps: [HelpStep]

    static func content(for screen: ScreenType) -> ScreenHelpContent {
        switch screen {
        case .taskList:
            return ScreenHelpContent(
                screenTitle: "Task List",
                screenIcon: "list.bullet.rectangle",
                steps: [
                    HelpStep(
                        title: "Add a Task",
                        description: "Tap the + button in the top-right corner to create a new task. You can set a title, due date, and notification preferences.",
                        icon: "plus.circle.fill",
                        iconColor: .green
                    ),
                    HelpStep(
                        title: "Complete a Task",
                        description: "Tap the circle next to a task to mark it as complete. Completed tasks will show a checkmark.",
                        icon: "checkmark.circle.fill",
                        iconColor: .blue
                    ),
                    HelpStep(
                        title: "Edit a Task",
                        description: "Tap on any task to open it for editing. You can change the title, due date, or notification settings.",
                        icon: "pencil.circle.fill",
                        iconColor: .orange
                    ),
                    HelpStep(
                        title: "Delete a Task",
                        description: "Swipe left on a task to reveal the delete option. You can also tap \"Clear Completed\" to remove all finished tasks.",
                        icon: "trash.circle.fill",
                        iconColor: .red
                    ),
                    HelpStep(
                        title: "Points of Interest",
                        description: "Tap the map pin icon to manage your saved locations. These are used for location-based task reminders.",
                        icon: "mappin.circle.fill",
                        iconColor: .purple
                    ),
                    HelpStep(
                        title: "Your Profile",
                        description: "Tap your profile avatar in the top-left to access account settings and sign out.",
                        icon: "person.circle.fill",
                        iconColor: .blue
                    )
                ]
            )

        case .addEditTask:
            return ScreenHelpContent(
                screenTitle: "Add/Edit Task",
                screenIcon: "square.and.pencil",
                steps: [
                    HelpStep(
                        title: "Task Title",
                        description: "Enter a descriptive title for your task. This is what you'll see in your task list.",
                        icon: "textformat",
                        iconColor: .blue
                    ),
                    HelpStep(
                        title: "Due Date",
                        description: "Set when your task is due. The date must be at least 5 minutes in the future.",
                        icon: "calendar",
                        iconColor: .orange
                    ),
                    HelpStep(
                        title: "Notification Type",
                        description: "Choose between Time-based (notify at a specific time) or Location-based (notify when near a place) reminders.",
                        icon: "bell.badge.fill",
                        iconColor: .purple
                    ),
                    HelpStep(
                        title: "Time Notification",
                        description: "For time-based tasks, choose how many minutes before the due date you want to be reminded.",
                        icon: "clock.fill",
                        iconColor: .green
                    ),
                    HelpStep(
                        title: "Location Notification",
                        description: "For location-based tasks, select a saved location and the distance at which you want to be notified.",
                        icon: "location.fill",
                        iconColor: .red
                    ),
                    HelpStep(
                        title: "Save Task",
                        description: "Tap Save to create or update your task. The button is disabled until all required fields are valid.",
                        icon: "checkmark.circle.fill",
                        iconColor: .blue
                    )
                ]
            )

        case .pointOfInterest:
            return ScreenHelpContent(
                screenTitle: "Points of Interest",
                screenIcon: "mappin.and.ellipse",
                steps: [
                    HelpStep(
                        title: "View Saved Locations",
                        description: "All your saved locations appear in the list. These are places you can use for location-based task reminders.",
                        icon: "list.bullet",
                        iconColor: .blue
                    ),
                    HelpStep(
                        title: "Add New Location",
                        description: "Tap the + button to add a new location. You can search for a place or drop a pin on the map.",
                        icon: "plus.circle.fill",
                        iconColor: .green
                    ),
                    HelpStep(
                        title: "Find Suggestions",
                        description: "Tap Suggestions to discover nearby stores, petrol stations, and pharmacies within 20km.",
                        icon: "sparkle.magnifyingglass",
                        iconColor: .purple
                    ),
                    HelpStep(
                        title: "Delete Location",
                        description: "Swipe left on any location to delete it. This won't affect existing tasks using that location.",
                        icon: "trash.circle.fill",
                        iconColor: .red
                    ),
                    HelpStep(
                        title: "Map View",
                        description: "Tap on a location to see it on the map. You can change map styles and explore the area.",
                        icon: "map.fill",
                        iconColor: .orange
                    )
                ]
            )

        case .userProfile:
            return ScreenHelpContent(
                screenTitle: "Account",
                screenIcon: "person.crop.circle",
                steps: [
                    HelpStep(
                        title: "Profile Info",
                        description: "View your account information including your name and email associated with your Apple ID.",
                        icon: "person.fill",
                        iconColor: .blue
                    ),
                    HelpStep(
                        title: "Sign Out",
                        description: "Tap Sign Out to log out of your account. You can sign in again anytime with your Apple ID.",
                        icon: "rectangle.portrait.and.arrow.right",
                        iconColor: .red
                    )
                ]
            )
        }
    }
}

// MARK: - Screen Help View

struct ScreenHelpView: View {
    let screenType: ScreenType
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private var content: ScreenHelpContent {
        ScreenHelpContent.content(for: screenType)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: content.screenIcon)
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    }

                    Text(content.screenTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Learn how to use this screen")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Steps carousel
                TabView(selection: $currentStep) {
                    ForEach(Array(content.steps.enumerated()), id: \.element.id) { index, step in
                        helpStepCard(step: step, index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<content.steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: index == currentStep ? 10 : 8, height: index == currentStep ? 10 : 8)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.vertical, 20)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }

                    Spacer()

                    Button(action: {
                        if currentStep < content.steps.count - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            dismiss()
                        }
                    }) {
                        HStack {
                            Text(currentStep < content.steps.count - 1 ? "Next" : "Got it!")
                            if currentStep < content.steps.count - 1 {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func helpStepCard(step: HelpStep, index: Int) -> some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.15))
                    .frame(width: 70, height: 70)
                Image(systemName: step.icon)
                    .font(.system(size: 30))
                    .foregroundColor(step.iconColor)
            }

            // Step number
            Text("Step \(index + 1) of \(content.steps.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

            // Title
            Text(step.title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Description
            Text(step.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 20)
    }
}

// MARK: - Help Button

struct HelpButton: View {
    let screenType: ScreenType
    @State private var showingHelp = false

    var body: some View {
        Button(action: {
            showingHelp = true
        }) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 18))
        }
        .sheet(isPresented: $showingHelp) {
            ScreenHelpView(screenType: screenType)
        }
    }
}
