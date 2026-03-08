//
//  GuidedTourManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Tour Step Definition

enum TourStep: Int, CaseIterable {
    case welcome
    case notesImportButton
    case addTaskButton
    case locationButton
    case complete

    var title: String {
        switch self {
        case .welcome:
            return "Welcome!"
        case .notesImportButton:
            return "Import from Notes"
        case .addTaskButton:
            return "Add a Task"
        case .locationButton:
            return "Points of Interest"
        case .complete:
            return "You're All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Let's take a quick tour of Smart Todo. This will only take a moment!"
        case .notesImportButton:
            return "Share text from Apple Notes or paste it here. AI groups items by location — like groceries to the supermarket, medicines to the pharmacy — and creates tasks with subtasks."
        case .addTaskButton:
            return "Tap + to create a task manually. Set due dates, choose time or location-based notifications, and add subtasks."
        case .locationButton:
            return "Save places like home, work, or stores. You'll get notified when you're near a location with pending tasks."
        case .complete:
            return "You're ready to go! Try importing from Notes using the share menu, or tap + to create your first task."
        }
    }

    var icon: String {
        switch self {
        case .welcome:
            return "hand.wave.fill"
        case .notesImportButton:
            return "note.text"
        case .addTaskButton:
            return "plus.circle.fill"
        case .locationButton:
            return "mappin.circle.fill"
        case .complete:
            return "checkmark.seal.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome:
            return .blue
        case .notesImportButton:
            return .orange
        case .addTaskButton:
            return .green
        case .locationButton:
            return .purple
        case .complete:
            return .green
        }
    }

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
    @Published var isCalendarImportComplete: Bool = false {
        didSet { UserDefaults.standard.set(isCalendarImportComplete, forKey: calendarImportCompletedKey) }
    }

    private let tourCompletedKey = "hasCompletedGuidedTour"
    private let onboardingCompletedKey = "hasCompletedOnboarding"
    private let poiSetupCompletedKey = "hasCompletedPOISetup"
    private let calendarImportCompletedKey = "hasCompletedCalendarImport"

    init() {
        // Load persisted values - use temporary variables to avoid triggering didSet during init
        let tourCompleted = UserDefaults.standard.bool(forKey: tourCompletedKey)
        let onboardingCompleted = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        let poiSetupCompleted = UserDefaults.standard.bool(forKey: poiSetupCompletedKey)
        let calendarImportCompleted = UserDefaults.standard.bool(forKey: calendarImportCompletedKey)

        self.hasCompletedTour = tourCompleted
        self.isOnboardingComplete = onboardingCompleted
        self.isPOISetupComplete = poiSetupCompleted
        self.isCalendarImportComplete = calendarImportCompleted
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
        isCalendarImportComplete = false
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

    private var shouldShowHighlight: Bool {
        switch step {
        case .welcome, .complete:
            return false
        default:
            return highlightFrame != nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay
                Color.black.opacity(0.75)

                // Highlight cutout with rounded corners
                if shouldShowHighlight, let frame = highlightFrame {
                    // Rounded rectangle cutout for the highlighted element
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: frame.width + 16, height: frame.height + 16)
                        .position(x: frame.midX, y: frame.midY)
                        .blendMode(.destinationOut)

                    // Glowing border around highlighted element
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(step.iconColor, lineWidth: 3)
                        .frame(width: frame.width + 16, height: frame.height + 16)
                        .position(x: frame.midX, y: frame.midY)
                        .shadow(color: step.iconColor.opacity(0.5), radius: 8)

                    // Pulsing ring animation
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(step.iconColor.opacity(0.4), lineWidth: 2)
                        .frame(width: frame.width + 24, height: frame.height + 24)
                        .position(x: frame.midX, y: frame.midY)
                        .modifier(PulseAnimation())
                }
            }
            .compositingGroup()
        }
        .allowsHitTesting(false)
    }
}

// Pulse animation modifier for the highlight ring
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.15 : 1.0)
            .opacity(isPulsing ? 0 : 0.6)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
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

    @State private var cardOffset: CGFloat = 30
    @State private var cardOpacity: Double = 0

    // Tooltip position based on step type - ALWAYS consistent
    private var tooltipPosition: TooltipPosition {
        switch step {
        case .welcome, .complete:
            return .center
        case .addTaskButton, .notesImportButton, .locationButton:
            return .belowHighlight
        }
    }

    private enum TooltipPosition {
        case center
        case belowHighlight
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                VStack {
                    switch tooltipPosition {
                    case .center:
                        Spacer()
                        tooltipCard
                        Spacer()

                    case .belowHighlight:
                        Spacer()
                            .frame(height: max(120, (highlightFrame?.maxY ?? 100) + 20))
                        tooltipCard
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                animateIn()
            }
            .onChange(of: step) { _, _ in
                animateOut()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    animateIn()
                }
            }
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            cardOffset = 0
            cardOpacity = 1
        }
    }

    private func animateOut() {
        cardOffset = 30
        cardOpacity = 0
    }

    private var tooltipCard: some View {
        VStack(spacing: 20) {
            // Icon with animated ring
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(step.iconColor.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: step.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(step.iconColor)
            }

            // Title and description
            VStack(spacing: 10) {
                Text(step.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(step.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Progress indicator
            progressIndicator

            // Action buttons
            actionButtons
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .offset(y: cardOffset)
        .opacity(cardOpacity)
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(TourStep.allCases, id: \.rawValue) { tourStep in
                Capsule()
                    .fill(tourStep == step ? step.iconColor : Color.gray.opacity(0.2))
                    .frame(width: tourStep == step ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
        .padding(.vertical, 4)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Back button (not on first or last step)
            if !isFirstStep && !isLastStep {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onPrevious()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }

            // Skip button (only on first step)
            if isFirstStep {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onSkip()
                }) {
                    Text("Skip")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
            }

            Spacer()

            // Next/Finish button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                if isLastStep {
                    onSkip()
                } else {
                    onNext()
                }
            }) {
                HStack(spacing: 6) {
                    Text(isLastStep ? "Get Started" : "Next")
                    if !isLastStep {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(step.iconColor)
                .cornerRadius(12)
                .shadow(color: step.iconColor.opacity(0.3), radius: 6, x: 0, y: 3)
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
