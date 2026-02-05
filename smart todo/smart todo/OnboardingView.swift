//
//  OnboardingView.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import SwiftUI
import CoreData
import MapKit
import CoreLocation

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var isAnimating = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "checkmark.circle.fill",
            iconColor: .blue,
            title: "Welcome to Smart Todo",
            subtitle: "Your intelligent task manager that helps you stay organized and never miss important tasks.",
            features: []
        ),
        OnboardingPage(
            icon: "list.bullet.clipboard.fill",
            iconColor: .green,
            title: "Organize Your Tasks",
            subtitle: "Create, manage, and complete tasks with ease. Stay on top of your daily activities.",
            features: [
                FeatureItem(icon: "plus.circle", text: "Quick task creation"),
                FeatureItem(icon: "checkmark.circle", text: "Mark tasks complete"),
                FeatureItem(icon: "trash", text: "Clear completed tasks")
            ]
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            iconColor: .orange,
            title: "Smart Notifications",
            subtitle: "Get reminded at the right time with flexible notification options.",
            features: [
                FeatureItem(icon: "clock", text: "Time-based reminders"),
                FeatureItem(icon: "calendar", text: "Set due dates"),
                FeatureItem(icon: "slider.horizontal.3", text: "Customize notification timing")
            ]
        ),
        OnboardingPage(
            icon: "location.fill",
            iconColor: .purple,
            title: "Location-Based Alerts",
            subtitle: "Get notified when you're near important places. Perfect for errands and location-specific tasks.",
            features: [
                FeatureItem(icon: "mappin.circle", text: "Save points of interest"),
                FeatureItem(icon: "location.magnifyingglass", text: "Discover nearby places"),
                FeatureItem(icon: "bell.and.waves.left.and.right", text: "Proximity notifications")
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    pages[currentPage].iconColor.opacity(0.1),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index], isAnimating: currentPage == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? pages[currentPage].iconColor : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.vertical, 20)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }

                    Spacer()

                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        HStack {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            Image(systemName: currentPage < pages.count - 1 ? "chevron.right" : "arrow.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(pages[currentPage].iconColor)
                        .cornerRadius(12)
                        .shadow(color: pages[currentPage].iconColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        withAnimation {
            isOnboardingComplete = true
            onComplete()
        }
    }
}

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let features: [FeatureItem]
}

struct FeatureItem {
    let icon: String
    let text: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isAnimating: Bool

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var featuresOffset: CGFloat = 30

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(page.iconColor.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                Image(systemName: page.icon)
                    .font(.system(size: 70))
                    .foregroundColor(page.iconColor)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }

            // Title and subtitle
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(textOpacity)

            // Features list
            if !page.features.isEmpty {
                VStack(spacing: 16) {
                    ForEach(Array(page.features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(page.iconColor.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: feature.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(page.iconColor)
                            }

                            Text(feature.text)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .offset(y: featuresOffset)
                        .opacity(textOpacity)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1), value: featuresOffset)
                    }
                }
                .padding(.top, 20)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            if isAnimating {
                startAnimations()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimations()
            } else {
                resetAnimations()
            }
        }
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            textOpacity = 1.0
            featuresOffset = 0
        }
    }

    private func resetAnimations() {
        iconScale = 0.5
        iconOpacity = 0
        textOpacity = 0
        featuresOffset = 30
    }
}

// MARK: - POI Setup View (shown after onboarding)

struct POISetupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var locationManager: LocationManager
    @Binding var isSetupComplete: Bool

    enum SetupStep {
        case locationPermission      // Initial permission request (When In Use)
        case alwaysPermission        // Request upgrade to Always
        case poiSelection
    }

    @State private var currentStep: SetupStep = .locationPermission
    @State private var isSearching = false
    @State private var suggestions: [MKMapItem] = []
    @State private var selectedSuggestions: Set<String> = []
    @State private var searchError: String?
    @State private var hasSearched = false
    @State private var permissionPhase: Int = 0  // 0 = not started, 1 = requesting when in use, 2 = requesting always

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                switch currentStep {
                case .locationPermission:
                    initialLocationPermissionContent
                case .alwaysPermission:
                    alwaysPermissionContent
                case .poiSelection:
                    poiSelectionContent
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Check if already authorized
            if locationManager.authorizationStatus == .authorizedAlways {
                currentStep = .poiSelection
            } else if locationManager.authorizationStatus == .authorizedWhenInUse {
                // Already has "While Using" - show always permission step
                currentStep = .alwaysPermission
            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                // Permission denied - go to POI selection
                currentStep = .poiSelection
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            handleAuthorizationChange(newStatus)
        }
    }

    private func handleAuthorizationChange(_ newStatus: CLAuthorizationStatus) {
        switch permissionPhase {
        case 1:
            // We requested "When In Use" permission
            if newStatus == .authorizedWhenInUse {
                // User granted "When In Use" - now ask for "Always"
                permissionPhase = 2
                withAnimation {
                    currentStep = .alwaysPermission
                }
            } else if newStatus == .authorizedAlways {
                // User granted "Always" directly (rare but possible)
                withAnimation {
                    currentStep = .poiSelection
                }
            } else if newStatus == .denied || newStatus == .restricted {
                // User denied - proceed to POI selection
                withAnimation {
                    currentStep = .poiSelection
                }
            }
        case 2:
            // We requested "Always" permission
            if newStatus == .authorizedAlways {
                withAnimation {
                    currentStep = .poiSelection
                }
            } else {
                // User didn't upgrade to Always - proceed anyway
                withAnimation {
                    currentStep = .poiSelection
                }
            }
        default:
            break
        }
    }

    // MARK: - Initial Location Permission Content (Step 1: Request When In Use)

    private var initialLocationPermissionContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 180, height: 180)

                Image(systemName: "location.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 32)

            // Title
            Text("Enable Location Services")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 12)

            // Description
            Text("Smart Todo uses your location to find nearby places and set up location-based reminders.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            // Features
            VStack(spacing: 16) {
                permissionFeatureRow(
                    icon: "mappin.and.ellipse",
                    color: .blue,
                    title: "Find Nearby Places",
                    description: "Discover stores, pharmacies, and more near you"
                )

                permissionFeatureRow(
                    icon: "bell.badge",
                    color: .orange,
                    title: "Location Reminders",
                    description: "Get notified when you're near important places"
                )

                permissionFeatureRow(
                    icon: "hand.raised.fill",
                    color: .green,
                    title: "Privacy First",
                    description: "Your location data stays on your device"
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: requestWhenInUsePermission) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("Enable Location")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(14)
                    .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }

                Button(action: skipLocationPermission) {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Always Permission Content (Step 2: Request Always Allow)

    private var alwaysPermissionContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 180, height: 180)

                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
            }
            .padding(.bottom, 32)

            // Success checkmark
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Location access enabled!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            .padding(.bottom, 16)

            // Title
            Text("Enable Background Location")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 12)

            // Description
            Text("To receive notifications when you arrive at saved places, Smart Todo needs \"Always Allow\" location access.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            // Features
            VStack(spacing: 16) {
                permissionFeatureRow(
                    icon: "bell.and.waves.left.and.right",
                    color: .purple,
                    title: "Arrival Alerts",
                    description: "Get notified when you arrive at a location"
                )

                permissionFeatureRow(
                    icon: "moon.fill",
                    color: .indigo,
                    title: "Works in Background",
                    description: "Notifications work even when app is closed"
                )

                permissionFeatureRow(
                    icon: "battery.100",
                    color: .green,
                    title: "Battery Efficient",
                    description: "Uses minimal battery with smart monitoring"
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: requestAlwaysPermission) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("Allow Always")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .cornerRadius(14)
                    .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
                }

                Button(action: skipAlwaysPermission) {
                    Text("Skip (Location notifications will be disabled)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private func permissionFeatureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func requestWhenInUsePermission() {
        permissionPhase = 1
        locationManager.requestWhenInUsePermission()
    }

    private func requestAlwaysPermission() {
        permissionPhase = 2
        locationManager.requestAlwaysPermissionUpgrade()
    }

    private func skipLocationPermission() {
        withAnimation {
            currentStep = .poiSelection
        }
    }

    private func skipAlwaysPermission() {
        withAnimation {
            currentStep = .poiSelection
        }
    }

    // MARK: - POI Selection Content

    private var poiSelectionContent: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }

                Text("Set Up Your Places")
                    .font(.title2)
                    .fontWeight(.bold)

                if !locationManager.isLocationBasedNotificationsAvailable {
                    // Warning about limited functionality
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Location notifications are disabled. Grant \"Always Allow\" in Settings to enable.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                } else {
                    Text("We'll find nearby stores, petrol stations, and pharmacies to help you set up location-based reminders.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.top, 30)
            .padding(.bottom, 24)

            if isSearching {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Finding nearby places...")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("This may take a few seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hasSearched && suggestions.isEmpty {
                // No results
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("No places found nearby")
                        .font(.headline)
                        .foregroundColor(.gray)

                    if let error = searchError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button("Try Again") {
                        searchNearbyPlaces()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !suggestions.isEmpty {
                // Results list
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(suggestions.count) places found")
                            .font(.headline)
                        Spacer()
                        Button(action: toggleSelectAll) {
                            Text(selectedSuggestions.count == suggestions.count ? "Deselect All" : "Select All")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)

                    List {
                        ForEach(suggestions) { item in
                            POISetupRow(
                                item: item,
                                isSelected: selectedSuggestions.contains(itemId(for: item)),
                                locationManager: locationManager
                            ) {
                                toggleSelection(for: item)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            } else {
                // Initial state - prompt to search
                VStack(spacing: 24) {
                    Spacer()

                    Button(action: searchNearbyPlaces) {
                        HStack(spacing: 12) {
                            Image(systemName: "location.magnifyingglass")
                                .font(.system(size: 20))
                            Text("Find Nearby Places")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .disabled(!locationManager.isLocationAuthorized)

                    Text("We'll search for stores, petrol stations,\nand pharmacies within 20km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
            }

            // Bottom buttons
            VStack(spacing: 12) {
                if !suggestions.isEmpty && !selectedSuggestions.isEmpty {
                    Button(action: addSelectedPlaces) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add \(selectedSuggestions.count) Place\(selectedSuggestions.count == 1 ? "" : "s")")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                    }
                }

                Button(action: skipSetup) {
                    Text(hasSearched ? "Skip for Now" : "Set Up Later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
        }
    }

    private func itemId(for item: MKMapItem) -> String {
        "\(item.location.coordinate.latitude)-\(item.location.coordinate.longitude)"
    }

    private func toggleSelection(for item: MKMapItem) {
        let id = itemId(for: item)
        if selectedSuggestions.contains(id) {
            selectedSuggestions.remove(id)
        } else {
            selectedSuggestions.insert(id)
        }
    }

    private func toggleSelectAll() {
        if selectedSuggestions.count == suggestions.count {
            selectedSuggestions.removeAll()
        } else {
            for item in suggestions {
                selectedSuggestions.insert(itemId(for: item))
            }
        }
    }

    private func searchNearbyPlaces() {
        isSearching = true
        searchError = nil

        Task {
            var searchCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            if let currentLocation = try? await locationManager.getCurrentLocation() {
                searchCenter = currentLocation.coordinate
            }

            let radiusInDegrees = 0.18
            let searchRegion = MKCoordinateRegion(
                center: searchCenter,
                span: MKCoordinateSpan(latitudeDelta: radiusInDegrees * 2, longitudeDelta: radiusInDegrees * 2)
            )

            let searchQueries = ["supermarket", "grocery store", "petrol station", "gas station", "pharmacy", "chemist"]
            var allResults: [MKMapItem] = []

            for query in searchQueries {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.region = searchRegion

                let search = MKLocalSearch(request: request)
                do {
                    let response = try await search.start()
                    allResults.append(contentsOf: response.mapItems)
                } catch {
                    print("Search error for \(query): \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                let maxDistance: CLLocationDistance = 20000
                let centerLocation = CLLocation(latitude: searchCenter.latitude, longitude: searchCenter.longitude)

                let filteredResults = allResults.filter { item in
                    let itemLocation = CLLocation(latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
                    return itemLocation.distance(from: centerLocation) <= maxDistance
                }

                var uniqueResults: [MKMapItem] = []
                var seenLocations: Set<String> = []
                for item in filteredResults {
                    let key = "\(String(format: "%.5f", item.location.coordinate.latitude))-\(String(format: "%.5f", item.location.coordinate.longitude))"
                    if !seenLocations.contains(key) {
                        seenLocations.insert(key)
                        uniqueResults.append(item)
                    }
                }

                let sortedResults = uniqueResults.sorted { item1, item2 in
                    let loc1 = CLLocation(latitude: item1.location.coordinate.latitude, longitude: item1.location.coordinate.longitude)
                    let loc2 = CLLocation(latitude: item2.location.coordinate.latitude, longitude: item2.location.coordinate.longitude)
                    return loc1.distance(from: centerLocation) < loc2.distance(from: centerLocation)
                }

                self.suggestions = Array(sortedResults.prefix(30))
                self.isSearching = false
                self.hasSearched = true
            }
        }
    }

    private func addSelectedPlaces() {
        for item in suggestions {
            let id = itemId(for: item)
            if selectedSuggestions.contains(id) {
                let newPOI = PointOfInterest(context: viewContext)
                newPOI.id = UUID()
                newPOI.name = item.name ?? "Unnamed Location"
                newPOI.latitude = item.location.coordinate.latitude
                newPOI.longitude = item.location.coordinate.longitude
                if let address = item.address {
                    newPOI.address = address.fullAddress
                }
                newPOI.createdAt = Date()
            }
        }

        do {
            try viewContext.save()
            isSetupComplete = true
        } catch {
            print("Error saving POIs: \(error)")
        }
    }

    private func skipSetup() {
        isSetupComplete = true
    }
}

struct POISetupRow: View {
    let item: MKMapItem
    let isSelected: Bool
    let locationManager: LocationManager
    let onTap: () -> Void

    private var categoryIcon: String {
        let name = (item.name ?? "").lowercased()
        if name.contains("petrol") || name.contains("gas") || name.contains("fuel") || name.contains("shell") || name.contains("bp") {
            return "fuelpump.fill"
        } else if name.contains("pharmacy") || name.contains("chemist") || name.contains("drug") {
            return "cross.case.fill"
        } else {
            return "cart.fill"
        }
    }

    private var categoryColor: Color {
        let name = (item.name ?? "").lowercased()
        if name.contains("petrol") || name.contains("gas") || name.contains("fuel") || name.contains("shell") || name.contains("bp") {
            return .orange
        } else if name.contains("pharmacy") || name.contains("chemist") || name.contains("drug") {
            return .green
        } else {
            return .blue
        }
    }

    private var distanceText: String {
        guard let currentLocation = locationManager.getCachedLocation() else { return "" }
        let itemLocation = CLLocation(latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
        let distance = itemLocation.distance(from: currentLocation)
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Category icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: categoryIcon)
                        .font(.system(size: 16))
                        .foregroundColor(categoryColor)
                }

                // Details
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name ?? "Unknown")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let address = item.address {
                        Text(address.shortAddress ?? address.fullAddress)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Distance
                Text(distanceText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
