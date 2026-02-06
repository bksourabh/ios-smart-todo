//
//  LocationManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import Foundation
import CoreLocation
import Combine
import CoreData
import UIKit

// MARK: - Region Entry Handler Protocol

protocol RegionEntryDelegate: AnyObject {
    func didEnterRegion(identifier: String)
    func didExitRegion(identifier: String)
}

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locationError: Error?
    @Published var monitoredRegions: Set<CLRegion> = []

    /// Returns true if location-based notifications are available (requires "Always Allow" permission)
    var isLocationBasedNotificationsAvailable: Bool {
        return authorizationStatus == .authorizedAlways
    }

    /// Returns true if basic location services are authorized (While Using or Always)
    var isLocationAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    weak var regionDelegate: RegionEntryDelegate?

    private var locationContinuation: CheckedContinuation<CLLocation?, Error>?
    private var cachedLocation: CLLocation?
    private var lastLocationUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 60 // Cache valid for 60 seconds

    // Minimum region radius (iOS recommends at least 100m for reliable detection)
    private let minimumRegionRadius: CLLocationDistance = 100

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters

        
        // Only start basic location updates if authorized (not background)
        // Background updates will be enabled explicitly when needed
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - Background Location Support
    // Note: UNLocationNotificationTrigger handles background location automatically
    // We don't need to manually enable allowsBackgroundLocationUpdates for notifications

    // MARK: - Region Monitoring (Geofencing)

    func startMonitoringRegion(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        print("=== Starting Region Monitoring ===")
        print("Region ID: \(identifier)")
        print("Center: (\(center.latitude), \(center.longitude))")
        print("Requested radius: \(radius)m")

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("ERROR: Region monitoring not available on this device")
            return
        }

        guard authorizationStatus == .authorizedAlways else {
            print("ERROR: Always authorization required for region monitoring (current: \(authorizationStatus.rawValue))")
            return
        }

        // Ensure radius is at least the minimum
        let effectiveRadius = max(radius, minimumRegionRadius)
        print("Effective radius: \(effectiveRadius)m")

        let region = CLCircularRegion(
            center: center,
            radius: effectiveRadius,
            identifier: identifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false

        locationManager.startMonitoring(for: region)
        monitoredRegions = Set(locationManager.monitoredRegions)
        print("Total monitored regions: \(monitoredRegions.count)")

        // Check if user is already in the region
        print("Requesting current state for region...")
        locationManager.requestState(for: region)

        print("=== Region Monitoring Setup Complete ===")
    }

    func stopMonitoringRegion(identifier: String) {
        for region in locationManager.monitoredRegions {
            if region.identifier == identifier {
                locationManager.stopMonitoring(for: region)
                break
            }
        }
        monitoredRegions = Set(locationManager.monitoredRegions)
    }

    func stopMonitoringAllRegions() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredRegions = Set(locationManager.monitoredRegions)
    }

    func isMonitoringRegion(identifier: String) -> Bool {
        return locationManager.monitoredRegions.contains { $0.identifier == identifier }
    }

    func getMonitoredRegionCount() -> Int {
        return locationManager.monitoredRegions.count
    }

    func requestLocationPermission() async -> Bool {
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        }

        // Request "When In Use" permission first (shows iOS system dialog)
        locationManager.requestWhenInUseAuthorization()

        // Wait for authorization status to change
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = $authorizationStatus
                .dropFirst()
                .sink { status in
                    cancellable?.cancel()
                    continuation.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
                }
        }
    }

    /// Request "When In Use" permission (Step 1 of two-step flow)
    func requestWhenInUsePermission() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    /// Request upgrade to "Always" permission (Step 2 of two-step flow)
    /// This should be called after user has granted "When In Use" permission
    func requestAlwaysPermissionUpgrade() {
        if authorizationStatus == .authorizedWhenInUse {
            // Request upgrade to "Always" - iOS will show the "Always Allow" prompt
            locationManager.requestAlwaysAuthorization()
        } else if authorizationStatus == .notDetermined {
            // If not yet determined, request Always directly
            locationManager.requestAlwaysAuthorization()
        } else {
            // Already have Always or permission denied - open Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// Returns cached location immediately if valid, otherwise fetches fresh location
    func getCurrentLocation() async throws -> CLLocation? {
        // Check authorization first
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.notAuthorized
        }

        // Return cached location if still valid (within last 60 seconds)
        if let cached = cachedLocation,
           let lastUpdate = lastLocationUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration {
            return cached
        }

        // Try to get location from CLLocationManager's last known location first
        if let lastKnown = locationManager.location,
           lastKnown.timestamp.timeIntervalSinceNow > -300 { // Within last 5 minutes
            cachedLocation = lastKnown
            lastLocationUpdate = Date()
            return lastKnown
        }

        // Request fresh location
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    /// Returns cached location instantly without waiting (may be nil or stale)
    func getCachedLocation() -> CLLocation? {
        // First try our cache
        if let cached = cachedLocation {
            return cached
        }
        // Fall back to CLLocationManager's last known location
        return locationManager.location
    }

    /// Request a fresh high-accuracy location update
    func requestHighAccuracyLocation() async throws -> CLLocation? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.notAuthorized
        }

        // Temporarily set to best accuracy for this request
        let previousAccuracy = locationManager.desiredAccuracy
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        defer {
            locationManager.desiredAccuracy = previousAccuracy
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    func checkAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }

    func startUpdatingLocation() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last { // Use most recent location
            currentLocation = location
            cachedLocation = location
            lastLocationUpdate = Date()
            locationError = nil
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error

        // Map CLLocationManager errors to our custom error types
        let mappedError: Error
        if let clError = error as? CLError {
            switch clError.code {
            case .denied, .locationUnknown:
                mappedError = LocationError.locationServicesDisabled
            default:
                mappedError = LocationError.locationUnavailable
            }
        } else {
            mappedError = error
        }

        locationContinuation?.resume(throwing: mappedError)
        locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        // Start basic location updates when authorized
        // Background updates are enabled explicitly via enableBackgroundLocationUpdates()
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }

        // Update monitored regions set
        monitoredRegions = Set(locationManager.monitoredRegions)
    }

    // MARK: - Region Monitoring Delegate Methods

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered region: \(region.identifier)")
        regionDelegate?.didEnterRegion(identifier: region.identifier)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited region: \(region.identifier)")
        regionDelegate?.didExitRegion(identifier: region.identifier)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        switch state {
        case .inside:
            print("Already inside region: \(region.identifier)")
            // User is already at the location - trigger notification
            regionDelegate?.didEnterRegion(identifier: region.identifier)
        case .outside:
            print("Outside region: \(region.identifier)")
        case .unknown:
            print("Unknown state for region: \(region.identifier)")
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Region monitoring failed: \(error.localizedDescription)")
        if let region = region {
            print("Failed region: \(region.identifier)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("Started monitoring region: \(region.identifier)")
        monitoredRegions = Set(locationManager.monitoredRegions)
    }
}

enum LocationError: LocalizedError {
    case notAuthorized
    case locationServicesDisabled
    case locationUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location permission not granted"
        case .locationServicesDisabled:
            return "Location services are disabled"
        case .locationUnavailable:
            return "Location is currently unavailable"
        }
    }
}
