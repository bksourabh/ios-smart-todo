//
//  GuidedTourManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import Combine

// MARK: - Tour Step Definition

enum TourStep: Int, CaseIterable {
    case welcome
    case addTaskButton
    case taskList
    case locationButton
    case profileButton
    case complete

    var title: String {
        switch self {
        case .welcome:
            return "Welcome!"
        case .addTaskButton:
            return "Add Your First Task"
        case .taskList:
            return "Your Tasks"
        case .locationButton:
            return "Points of Interest"
        case .profileButton:
            return "Your Profile"
        case .complete:
            return "You're All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Let's take a quick tour of Smart Todo. This will only take a moment!"
        case .addTaskButton:
            return "Tap the + button to create a new task. You can add details like due dates and notification preferences."
        case .taskList:
            return "Your tasks will appear here. Tap the circle to mark them complete, or tap the task to edit it."
        case .locationButton:
            return "Manage your saved locations here. Add places like home, work, or stores for location-based reminders."
        case .profileButton:
            return "Access your account settings and sign out from here."
        case .complete:
            return "You're ready to start using Smart Todo! Add your first task to get started."
        }
    }

    var icon: String {
        switch self {
        case .welcome:
            return "hand.wave.fill"
        case .addTaskButton:
            return "plus.circle.fill"
        case .taskList:
            return "list.bullet"
        case .locationButton:
            return "mappin.circle.fill"
        case .profileButton:
            return "person.circle.fill"
        case .complete:
            return "checkmark.seal.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome:
            return .blue
        case .addTaskButton:
            return .green
        case .taskList:
            return .orange
        case .locationButton:
            return .purple
        case .profileButton:
            return .blue
        case .complete:
            return .green
        }
    }

    var highlightAnchor: TourHighlightAnchor {
        switch self {
        case .welcome:
            return .center
        case .addTaskButton:
            return .topRight
        case .taskList:
            return .center
        case .locationButton:
            return .topRight
        case .profileButton:
            return .topLeft
        case .complete:
            return .center
        }
    }
}

enum TourHighlightAnchor {
    case topLeft
    case topRight
    case center
    case bottomLeft
    case bottomRight
}

// MARK: - Guided Tour Manager

@MainActor
final class GuidedTourManager: ObservableObject {
    static let shared = GuidedTourManager()

    @Published var isShowingTour: Bool = false
    @Published var currentStep: TourStep = .welcome
    @Published var hasCompletedTour: Bool = false {
        didSet { UserDefaults.standard.set(hasCompletedTour, forKey: tourCompletedKey) }
    }
    @Published var isOnboardingComplete: Bool = false {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: onboardingCompletedKey) }
    }
    @Published var isPOISetupComplete: Bool = false {
        didSet { UserDefaults.standard.set(isPOISetupComplete, forKey: poiSetupCompletedKey) }
    }

    private let tourCompletedKey = "hasCompletedGuidedTour"
    private let onboardingCompletedKey = "hasCompletedOnboarding"
    private let poiSetupCompletedKey = "hasCompletedPOISetup"

    init() {
        // Load persisted values - use temporary variables to avoid triggering didSet during init
        let tourCompleted = UserDefaults.standard.bool(forKey: tourCompletedKey)
        let onboardingCompleted = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        let poiSetupCompleted = UserDefaults.standard.bool(forKey: poiSetupCompletedKey)

        self.hasCompletedTour = tourCompleted
        self.isOnboardingComplete = onboardingCompleted
        self.isPOISetupComplete = poiSetupCompleted
    }

    func startTour() {
        currentStep = .welcome
        isShowingTour = true
    }

    func nextStep() {
        let allSteps = TourStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex + 1 < allSteps.count {
            withAnimation(.spring(response: 0.4)) {
                currentStep = allSteps[currentIndex + 1]
            }

            if currentStep == .complete {
                completeTour()
            }
        }
    }

    func previousStep() {
        let allSteps = TourStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex > 0 {
            withAnimation(.spring(response: 0.4)) {
                currentStep = allSteps[currentIndex - 1]
            }
        }
    }

    func skipTour() {
        completeTour()
    }

    func completeTour() {
        hasCompletedTour = true
        withAnimation {
            isShowingTour = false
        }
    }

    func resetTour() {
        hasCompletedTour = false
        currentStep = .welcome
    }

    func resetOnboarding() {
        isOnboardingComplete = false
        isPOISetupComplete = false
        resetTour()
    }
}

// MARK: - Tour Overlay View

struct GuidedTourOverlay: View {
    @ObservedObject var tourManager: GuidedTourManager
    let highlightFrames: [TourStep: CGRect]

    var body: some View {
        if tourManager.isShowingTour {
            ZStack {
                // Semi-transparent background with cutout
                TourBackgroundMask(
                    step: tourManager.currentStep,
                    highlightFrame: highlightFrames[tourManager.currentStep]
                )
                .ignoresSafeArea()

                // Tooltip card
                TourTooltipCard(
                    step: tourManager.currentStep,
                    highlightFrame: highlightFrames[tourManager.currentStep],
                    onNext: { tourManager.nextStep() },
                    onPrevious: { tourManager.previousStep() },
                    onSkip: { tourManager.skipTour() },
                    isFirstStep: tourManager.currentStep == .welcome,
                    isLastStep: tourManager.currentStep == .complete
                )
            }
            .transition(.opacity)
        }
    }
}

struct TourBackgroundMask: View {
    let step: TourStep
    let highlightFrame: CGRect?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay
                Color.black.opacity(0.7)

                // Highlight cutout (if not center-focused step)
                if let frame = highlightFrame, step.highlightAnchor != .center {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: frame.width + 20, height: frame.height + 20)
                        .position(x: frame.midX, y: frame.midY)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
        }
        .allowsHitTesting(false)
    }
}

struct TourTooltipCard: View {
    let step: TourStep
    let highlightFrame: CGRect?
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSkip: () -> Void
    let isFirstStep: Bool
    let isLastStep: Bool

    @State private var cardOffset: CGFloat = 50
    @State private var cardOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if shouldShowAbove(in: geometry) {
                    Spacer()
                }

                tooltipContent
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 24)
                    .offset(y: cardOffset)
                    .opacity(cardOpacity)

                if !shouldShowAbove(in: geometry) {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    cardOffset = 0
                    cardOpacity = 1
                }
            }
            .onChange(of: step) { _, _ in
                cardOffset = 50
                cardOpacity = 0
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    cardOffset = 0
                    cardOpacity = 1
                }
            }
        }
    }

    private func shouldShowAbove(in geometry: GeometryProxy) -> Bool {
        if let frame = highlightFrame {
            return frame.midY < geometry.size.height / 2
        }
        return false
    }

    private var tooltipContent: some View {
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

            // Title and description
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.title3)
                    .fontWeight(.bold)

                Text(step.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Progress dots
            HStack(spacing: 6) {
                ForEach(TourStep.allCases, id: \.rawValue) { tourStep in
                    Circle()
                        .fill(tourStep == step ? step.iconColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Buttons
            HStack(spacing: 12) {
                if !isFirstStep && !isLastStep {
                    Button(action: onPrevious) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }

                if !isLastStep && isFirstStep {
                    Button(action: onSkip) {
                        Text("Skip Tour")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                }

                Spacer()

                Button(action: isLastStep ? onSkip : onNext) {
                    HStack {
                        Text(isLastStep ? "Get Started" : "Next")
                        if !isLastStep {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(step.iconColor)
                    .cornerRadius(10)
                }
            }
        }
    }
}

// MARK: - Highlight Frame Preference Key

struct HighlightFramePreferenceKey: PreferenceKey {
    static var defaultValue: [TourStep: CGRect] = [:]

    static func reduce(value: inout [TourStep: CGRect], nextValue: () -> [TourStep: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - View Extension for Tour Highlights

extension View {
    func tourHighlight(for step: TourStep) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: HighlightFramePreferenceKey.self,
                        value: [step: geometry.frame(in: .global)]
                    )
            }
        )
    }
}
