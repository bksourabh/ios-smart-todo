//
//  LocationManager.swift
//  smart todo
//
//  Created by Sourabh Mazumder on 4/1/2026.
//

import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locationError: Error?

    private var locationContinuation: CheckedContinuation<CLLocation?, Error>?
    private var cachedLocation: CLLocation?
    private var lastLocationUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 60 // Cache valid for 60 seconds

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Faster initial location
        authorizationStatus = locationManager.authorizationStatus

        // Start monitoring location updates in background for faster access
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func requestLocationPermission() async -> Bool {
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        }

        // Request "Always" permission to show both "While Using" and "Always" options
        locationManager.requestAlwaysAuthorization()

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
        // Start location updates when authorized
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
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
